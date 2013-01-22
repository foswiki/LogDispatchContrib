# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch;

use strict;
use warnings;
use utf8;

use Assert;

use Foswiki::Logger ();
our @ISA = ('Foswiki::Logger');

=begin TML

---+ package Foswiki::Logger::LogDispatch

use Log::Dispatch to allow logging to almost anything.

=cut

use Log::Dispatch;
use Foswiki::Time         ();
use Foswiki::ListIterator ();

# Local symbol used so we can override it during unit testing
sub _time { return time() }

use constant TRACE => 0;

sub new {
    my $class   = shift;
    my $binmode = '';
    my $log     = '';
    my %methods;

    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        $binmode .= ":encoding($Foswiki::cfg{Site}{CharSet})";
    }

    return bless(
        {
            dispatch    => $log,
            binmode     => $binmode,
            methods     => \%methods,
            acceptsHash => 1,
        },
        $class
    );
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    undef $this->{dispatch};
    undef $this->{binmode};
    undef $this->{methods};

}

sub init {
    my $this = shift;

    $this->{dispatch} = Log::Dispatch->new();

    foreach my $logtype ( keys %{ $Foswiki::cfg{Log}{LogDispatch} } ) {

        # These are not logging methods
        next if $logtype eq 'MaskIP';
        next if $logtype eq 'EventIterator';
        next unless ( $Foswiki::cfg{Log}{LogDispatch}{$logtype}{Enabled} );

        my $logMethod = 'Foswiki::Logger::LogDispatch::' . $logtype;
        eval "require $logMethod";
        if ($@) {
            print STDERR
">>>> Failed to load Foswiki::Logger::LogDispatch::$logtype: $@ \n";
        }
        else {
            $this->{methods}->{$logtype} = $logMethod->new($this);
        }
    }
}

=begin TML

---++ ObjectMethod binmode()
Return the binmode for used in reading and writing to logs.

=cut

sub binmode {
    my $this = shift;
    return $this->{binmode};
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

---+++ Compatibility interface:
 $this->logger->log( 'info', $user, $action, $webTopic, $message, $remoteAddr );
 $this->logger->log( 'warning', $mess );
 $this->logger->log( 'debug', $mess );

---+++ Native interface:
 $this->logger->log( { level      => 'info',
                       user       => $user,
                       action     => $action,
                       webTopic   => $webTopic,
                       extra      => $string or \@fields,
                       remoteAddr => $remoteAddr } );

 $this->logger->log( { level => 'warning',
                       caller => $caller,
                       extra  => $string or \@fields } );

 $this->logger->log( { level => 'debug',
                       extra  => $string or \@fields } );

Fields recorded for info messages are generally fixed.  Any levels other than info
can be called with an array of additional fields to log.

=cut

sub log {
    my $this = shift;
    my $fhash;

    # Native interface:  Just pass through the hash
    if ( ref( $_[0] ) eq 'HASH' ) {
        $fhash = shift;
    }

    # Compatibility interface. Fixed fields are mapped into the hash
    # and remaining fields are passed for later processing.
    else {
        $fhash->{level} = shift;

        if ( $fhash->{level} eq 'info' ) {
            $fhash->{user}       = shift;
            $fhash->{action}     = shift;
            $fhash->{webTopic}   = shift;
            $fhash->{extra}      = shift;
            $fhash->{remoteAddr} = shift;
        }
        else {
            $fhash->{extra} = \@_;
        }
    }

    # Implement the core event filter
    return
      if ( $fhash->{level} eq 'info'
        && defined $fhash->{action}
        && defined $Foswiki::cfg{Log}{Action}{ $fhash->{action} }
        && !$Foswiki::cfg{Log}{Action}{ $fhash->{action} } );

    Foswiki::Logger::setCommonFields($fhash)
      if ( $Foswiki::Plugins::VERSION > 2.2 );

    $fhash->{extra} = join( ' ', @{ $fhash->{extra} } )
      if ( ref( $fhash->{extra} ) eq 'ARRAY' );

    $fhash->{logd} = $this;    # Logger object needed for some loggers.
    $fhash->{message} ||=
      '';    # Required field that will be overwritten by a callback.

    my $now = _time();
    $fhash->{timestamp} = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    $this->init() unless $this->{dispatch};

    # Optional obfsucation of IP addresses for some locations.  However
    # preserve them for auth failures.
    if (   defined $Foswiki::cfg{Log}{LogDispatch}{MaskIP}
        && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} ne 'none'
        && defined $fhash->{remoteAddr} )
    {
        unless ( $fhash->{extra} =~ /^AUTHENTICATION FAILURE/ ) {

            if ( $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x' ) {
                $fhash->{remoteAddr} = 'x.x.x.x';
            }
            else {

                # defaults to Hash of IP
                use Digest::MD5 qw( md5_hex );
                my $md5hex = md5_hex( $fhash->{remoteAddr} );
                $fhash->{remoteAddr} =
                    hex( substr( $md5hex, 0, 2 ) ) . '.'
                  . hex( substr( $md5hex, 2, 2 ) ) . '.'
                  . hex( substr( $md5hex, 4, 2 ) ) . '.'
                  . hex( substr( $md5hex, 6, 2 ) );
            }
        }
    }

    # Dispatch all of the registred output classes
    $this->{dispatch}->log(%$fhash);

    # And any discrete logging per handler
    foreach my $method ( keys %{ $this->{methods} } ) {
        my $handler = $this->{methods}->{$method};
        if ( $handler->can('log') ) {
            print STDERR " LogDispatch.pm thinks $method should LOG \n"
              if TRACE;
            $handler->log($fhash);
        }
    }
}

=begin TML

---++ ObjectMethod _flattenLog( %logHash )

This is a callback used by the flat file loggers to flatten the logged
fields into a single record per a format token.

=cut

sub _flattenLog {

    my %logHash = @_;

#use Data::Dumper qw( Dumper );
#use Carp qw<longmess>;
#my $mess = longmess();
#print STDERR "===== CALLER =====\n" . Dumper ( $mess ) . "========\n";
#print STDERR "===== INCOMING PARAMS ===\n" . Dumper( @_ ) . "========\n";
#print STDERR "===== INCOMING HASH ===\n" . Dumper( %logHash ) . "========\n";
#print STDERR "===== CONFIG HASH ===\n" . Dumper( $Foswiki::cfg{Log}{LogDispatch}{FlatLayout} ) . "========\n";

    my $logLayout_ref = $logHash{Layout_ref};

    my @line;    # Collect the results
    foreach ( @$logLayout_ref[ 1 .. $#{$logLayout_ref} ] ) {
        if ( ref($_) eq 'ARRAY' ) {
            push @line,
              join(
                @{$_}[0],
                map( ( $logHash{$_} || '' ), @{$_}[ 1 .. $#{$_} ] )
              );
        }
        else {
            push @line, ( $logHash{$_} || '' );
        }
    }

    # Extract non-blank characters from delimiter for encoding
    my ($delim) = @$logLayout_ref[0] =~ m/(\S+)/;
    my $ldelim  = @$logLayout_ref[0];
    my $tdelim  = @$logLayout_ref[0];
    $ldelim =~ s/^\s+//g;
    $tdelim =~ s/\s+$//g;

    my $message = $ldelim
      . join(
        @$logLayout_ref[0],
        map { s/([$delim\n])/'&#255;&#'.ord($1).';'/gex; $_ } @line
      ) . $tdelim;

    print STDERR "FLAT MESSAGE: ($message) \n" if TRACE;

    # Item10764, SMELL UNICODE: actually, perhaps we should open the stream this
    # way for any encoding, not just utf8. Babar says: check what Catalyst does.
    unless ( $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        if ( utf8::is_utf8($message) ) {
            require Encode;
            $message =
              Encode::encode( $Foswiki::cfg{Site}{CharSet}, $message, 0 );
        }
    }

    return $message;
}

=begin TML

---++ StaticMethod eachEventSince($time, \@levels, [qw/field list/]) -> $iterator

See Foswiki::Logger for the interface.

Copied from Foswiki::PlainFile logger.

This logger implementation maps groups of levels to a single logfile, viz.  By default:
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
   * =debug= messages are output together.
The actual groupings are configurable.

=cut

sub eachEventSince {

    my $this  = shift;
    my $time  = shift;
    my $level = shift;

    $this->init() unless $this->{dispatch};

    my $cfgHandlers = $Foswiki::cfg{Log}{LogDispatch}{EventIterator}{$level}
      || 'FileRolling,File';

    my @eventHandlers = split( ',', $cfgHandlers );
    my $handler;
    my $eventHandler;

    foreach (@eventHandlers) {
        if ( $Foswiki::cfg{Log}{LogDispatch}{$_}{Enabled} ) {
            $handler      = $this->{methods}->{$_};
            $eventHandler = $_;
            last;
        }
    }

    unless ( $handler && $handler->can('eachEventSince') ) {
        Foswiki::Func::writeWarning(
            "eachEventSince not supported for $eventHandler.");
        require Foswiki::ListIterator;
        return new Foswiki::ListIterator( [] );
    }

    return $handler->eachEventSince( $time, $level );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit, GeorgeClark

Copyright (C) 2012 SvenDowideit@fosiki.com,  Foswiki Contributors.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution.  NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
