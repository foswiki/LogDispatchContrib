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

use constant TRACE => 1;

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

    return
      bless( { dispatch => $log, binmode => $binmode, methods => \%methods },
        $class );
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

=cut

sub log {
    my ( $this, $level, @fields ) = @_;
    my %fhash;
    $fhash{level} = $level;
    $fhash{message} =
      '';    # Required field that will be overwritten by a callback.
    my $fn = 0;

    $this->init() unless $this->{dispatch};

    # Event type info is logged with following format:
    # 'info', $user, $action, $webTopic, $extra, $remoteAddr
    # Other logs are undefined, passing an array of "stuff"

# The LogDispatch log call requires a hash,  so convert the field array into a hash
# File, FileRolling, Screen and Syslog will all use _flattenLog callback to convert
# back to a flat log message.   The DBI logger will access the individual fields.

    foreach my $fld (@fields) {
        print STDERR "field $fn = $fld \n" if TRACE;
        $fhash{$fn} = $fld;
        $fn++;
    }

    $this->{dispatch}->log(%fhash);

}

sub _flattenLog {

    my %p = @_;
    my @fields;

    print STDERR "_flattenLog called - LEVEL $p{level}\n";

    for ( my $i = 0 ; $i < scalar keys %p ; $i++ ) {
        push( @fields, $p{$i} ) if defined $p{$i};
    }

    my $now = _time();
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift( @fields, "$time $p{level}" );

    # Optional obfsucation of IP addresses for some locations.  However
    # preserve them for auth failures.
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{MaskIP}
        && $Foswiki::cfg{Log}{LogDispatch}{MaskIP} ne 'none' )
    {
        if ( scalar @fields > 4 ) {
            unless ( $fields[4] =~ /^AUTHENTICATION FAILURE/ )

             # SMELL This isn't correct.
             #                && $fields[5] =~
             #                /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ )
            {

                if ( $Foswiki::cfg{Log}{LogDispatch}{MaskIP} eq 'x.x.x.x' ) {
                    $fields[5] = 'x.x.x.x';
                }
                else {

                    # defaults to Hash of IP
                    use Digest::MD5 qw( md5_hex );
                    my $md5hex = md5_hex( $fields[5] );
                    $fields[5] =
                        hex( substr( $md5hex, 0, 2 ) ) . '.'
                      . hex( substr( $md5hex, 2, 2 ) ) . '.'
                      . hex( substr( $md5hex, 4, 2 ) ) . '.'
                      . hex( substr( $md5hex, 6, 2 ) );
                }
            }
        }
    }

    my $message =
      '| ' . join( ' | ', map { s/\|/&vbar;/g; $_ } @fields ) . ' |';

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

---++ StaticMethod eachEventSince($time, $level) -> $iterator

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

    my @eventHandlers =
      split( ',', $Foswiki::cfg{Log}{LogDispatch}{EventIterator}{$level} );
    my $handler;
    my $eventHandler;

    foreach $eventHandler (@eventHandlers) {
        if ( $Foswiki::cfg{Log}{LogDispatch}{$eventHandler}{Enabled} ) {
            $handler = $this->{methods}->{$eventHandler};
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
