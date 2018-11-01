# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::Base;

use strict;
use warnings;

use constant TRACE => 0;

use Assert;
use Fcntl qw(:flock);
use Foswiki::Logger::LogDispatch::EventIterator ();

our @ISA = qw/Foswiki::Logger::LogDispatch::EventIterator/;

=begin TML

---+ package Foswiki::Logger::LogDispatch::Base

base class for all log dispatch handlers

=cut

sub new {
    my $class = shift;
    my $logd  = shift;

    $class =~ /.*::(.*?)$/;
    my $type = $1;

    print STDERR "init'ing logger of type $type\n" if TRACE;

    return unless $Foswiki::cfg{Log}{LogDispatch}{$type}{Enabled};

    my $this = bless(
        {
            type => $type,
            logd => $logd,
            @_
        },
        $class
    );

    unless ( defined $Foswiki::cfg{Log}{LogDispatch}{$type}{Layout} ) {
        $Foswiki::cfg{Log}{LogDispatch}{Syslog}{Layout} = {
            info => [
                ' | ', [ ' ', 'timestamp', 'level' ],
                'user', 'action',
                'webTopic', [ ' ', 'extra', 'agent', ],
                'remoteAddr'
            ],
            DEFAULT => [
                ' | ',
                [ ' ', 'timestamp', 'level' ],
                [ ' ', 'caller',    'extra' ]
            ],
        };
    }

    # call class specific init
    $this->init();

    return $this;
}

=begin TML

---++ ObjectMethod DESTROY()

Break circular references.

=cut

sub DESTROY {
    my $this = shift;

    flock( $this->{handle}, LOCK_UN ) if defined $this->{logLocked};
    close( delete $this->{handle} ) if defined $this->{handle};

    undef $this->{fileLevels};
    undef $this->{logd};
    undef $this->{logDir};
}

=begin TML

---++ ObjectMethod eachEventSince()

Determine the file needed to provide the requested event level, and return an iterator for the file.

=cut

sub eachEventSince {
    die "not implemented";
}

=begin TML

---++ ObjectMethod init()

called during object construction when this logger is enabled

=cut

sub init {

    # nop by default
}

# Get the name of the log for a given reporting level
sub getLogForLevel {
    my ( $this, $level ) = @_;

    my %level2num = (
        debug     => 0,
        info      => 1,
        notice    => 2,
        warning   => 3,
        error     => 4,
        critical  => 5,
        alert     => 6,
        emergency => 7,
    );

    my $file;
    foreach my $testfile ( keys %{ $this->{fileLevels} } ) {
        my ( $min_level, $max_level ) =
          split( /:/, $this->{fileLevels}->{$testfile} );
        print STDERR " $testfile splits to min $min_level max $max_level\n"
          if TRACE;
        if (   $level2num{$min_level} <= $level2num{$level}
            && $level2num{$max_level} >= $level2num{$level} )
        {
            $file = $testfile;
            last;
        }
    }

    print STDERR "Decoded level $level to file $file\n" if TRACE;

    ASSERT( defined $file && $file ) if DEBUG;
    my $log = $Foswiki::cfg{Log}{Dir} . '/' . $file . '.log';

    # SMELL: Expand should not be needed, except if bin/configure tries
    # to log to locations relative to $Foswiki::cfg{WorkingDir}, DataDir, etc.
    # Windows seemed to be the most difficult to fix - this was the only thing
    # that I could find that worked all the time.
    Foswiki::Configure::Load::expandValue($log);
    return $log;
}

=begin TML

---++ ObjectMethod flattenLog()

Provides a default layout if configure neglected to include one for the File logger,
and then call the Foswiki::Logger::LogDispatch::flattenLog() utility routine.

=cut

sub flattenLog {

    my $this  = shift;
    my $level = '';

# Benchmark shows it's 30% faster to scan the parameter array rather than convert it to a hash

# SMELL: pre-optimization it seems; revert when it's clear what this actualy intends to achieve

    for ( my $e = 0 ; $e < scalar @_ ; $e += 2 ) {
        if ( $_[$e] eq 'level' ) {
            $level = $_[ $e + 1 ];
            last;
        }
    }

    my $logLayout_ref =
      (
        defined $Foswiki::cfg{Log}{LogDispatch}{ $this->{type} }{Layout}{$level}
      )
      ? $Foswiki::cfg{Log}{LogDispatch}{ $this->{type} }{Layout}{$level}
      : $Foswiki::cfg{Log}{LogDispatch}{ $this->{type} }{Layout}{DEFAULT};

    push @_, _Layout_ref => $logLayout_ref;

    $this->{logd}->flattenLog(@_);
}

=begin TML

---++ ObjectMethod logDir()

returns the log directory

=cut

sub logDir {
    my $this = shift;

    my $logDir = $this->{logDir};

    unless ( defined $logDir ) {
        $logDir = $Foswiki::cfg{Log}{Dir};
        Foswiki::Configure::Load::expandValue($logDir);
        $this->{logDir} = $logDir;
    }

    return $logDir;
}

1;

__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2018 Foswiki Contributors,  Foswiki Contributors.
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
