# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::EventIterator;

use strict;
use warnings;

use constant TRACE => 0;

use Assert;
use Fcntl qw(:flock);
use Time::ParseDate       ();
use Foswiki::LineIterator ();
use Foswiki::Iterator     ();
our @ISA = ('Foswiki::Iterator');

sub new {
    my ( $class, $time, $level, $doLock ) = @_;

    my $this = bless(
        {
            _time          => $time,
            _level         => $level,
            _doLock        => $doLock,
            _files         => [],
            _nextFileIndex => 0,
        },
        $class
    );

    print STDERR "EventIterator: time=$time, level=$level, doLock="
      . ( $doLock ? "1" : "0" ) . "\n"
      if TRACE;

    return $this;
}

sub DESTROY {
    my $this = shift;

    $this->_closeLogFile;

    undef $this->{_time};
    undef $this->{_level};
    undef $this->{_files};
    undef $this->{_nextFileIndex};
}

sub reset {
    my $this = shift;

    $this->_closeLogFile;
    $this->{_nextFileIndex} = 0;

    return 1;
}

sub _openNextFile {
    my $this = shift;

    print STDERR
      "EventIterator: called openNextFile, index=$this->{_nextFileIndex}\n"
      if TRACE;

    # close the previous log file
    $this->_closeLogFile;

    my $filename = $this->{_files}[ $this->{_nextFileIndex} ];
    return unless defined $filename;

    print STDERR "EventIterator: opening file $filename\n" if TRACE;

    $this->{_nextFileIndex}++;

    my $fh;
    unless ( open( $fh, '<:encoding(utf-8)', $filename ) ) {
        print STDERR "EventIterator: Failed to open $filename: $!\n";
        return $this->_openNextFile;
    }

    # peek first and last event
    my $firstLine;
    my $lastLine;
    my $firstEvent;
    my $lastEvent;
    while ( my $line = <$fh> ) {
        next if $line =~ /^\s*$/;
        next unless $line =~ /\b$this->{_level}\b/;    # test the level
        unless ( defined $firstLine ) {
            $firstLine  = $line;
            $firstEvent = $this->_extractEvent($firstLine);
            last if $firstEvent;    # yes, we need to process this logfile
        }
        $lastLine = $line;
    }

    unless ($firstEvent) {          # maybe a later event up to the last one
        my $lastEvent = $this->_extractEvent($lastLine);
        return $this->_openNextFile unless $lastEvent;
    }

    seek( $fh, 0, 0 );              #rewind
    $this->{_lineIter} = new Foswiki::LineIterator($fh);

    if ( $this->{_doLock} ) {
        $this->{_fileLock} =
          eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
    }

    $this->{_handle} = $fh;

    return $this->{_handle};
}

sub _closeLogFile {
    my $this = shift;

    if ( defined $this->{_handle} ) {
        print STDERR "EventIterator: closing recent log file\n" if TRACE;
        flock( $this->{_handle}, LOCK_UN ) if $this->{_fileLock};
        close( $this->{_handle} );
    }

    undef $this->{_handle};
    undef $this->{_lineIter};
    undef $this->{_fileLock};
}

sub addLogFile {
    my ( $this, $filename ) = @_;

    return unless -r $filename;    # silently ignore

    print STDERR "EventIterator: adding logfile $filename\n" if TRACE;

    push @{ $this->{_files} }, $filename;
}

sub hasNext {
    my $this = shift;

    return 1 if defined $this->{_nextEvent};

#print STDERR "EventIterator: called hasNext, lineIter=".($this->{_lineIter}//'undef')."\n" if TRACE;

    if ( !defined( $this->{_lineIter} )
        || ( $this->{_lineIter} && !$this->{_lineIter}->hasNext() ) )
    {
        return 0 unless $this->_openNextFile();
    }

    while ( $this->{_lineIter}->hasNext() ) {
        my $ln    = $this->{_lineIter}->next();
        my $event = $this->_extractEvent($ln);
        if ($event) {
            $this->{_nextEvent} = $event;
            return 1;
        }
    }

    $this->_closeLogFile;
    return $this->hasNext;
}

sub _extractEvent {
    my ( $this, $line ) = @_;

    $line =~ s/&#255;&#10;/\n/g;    # Reverse newline encoding

    #SMELL: This whole process needs to reverse the record as defined
    #       in LogDispatch::flattenLog and the configuration.

    my @event = split( /\s*\|\s*/, $line );
    shift @event;    # skip the leading empty cell

    return unless scalar(@event) && defined $event[0];

    if (
        $event[0] =~ s/\s+$this->{_level}\s*$//      # test the level
        || $event[0] =~ /^\d{1,2} [a-z]{3} \d{4}/i
        && $this->{_level} eq
        'info' # accept a plain 'old' format date with no level only if reading info (statistics)
      )
    {
        $event[0] = Time::ParseDate::parsedate( $event[0] );
        return unless defined $event[0];    # Skip event if time doesn't decode.
        return if $event[0] < $this->{_time};    # test the time
    }

    return \@event;
}

sub next {
    my $this = shift;

    my ( $fhash, $data ) = $this->_parseEvent();

    #use Data::Dumper;
    #print STDERR '_nextEvent ' . Data::Dumper::Dumper( \$this->{_nextEvent} ) .
    #             '$fhash ' . Data::Dumper::Dumper( \$fhash ) .
    #             '$data ' . Data::Dumper::Dumper( \$data ) .
    #             "\n";

    undef $this->{_nextEvent};
    return $data;
}

sub _parseEvent {
    my ( $this, $data ) = @_;

    $data ||= $this->{_nextEvent};    # Array ref of raw fields from record.
    my $level = $this->{_level};      # Level parsed from record or assumed.
    my %fhash;                        # returned hash of identified fields
    $fhash{level} = $level;

#SMELL: This assumes a fixed layout record.  Needs to be updated to reverse the process
#       performed in Log::Dispatch::flattenLog()
    if ( $level eq 'info' ) {
        $fhash{epoch}      = shift @$data;
        $fhash{user}       = shift @$data;
        $fhash{action}     = shift @$data;
        $fhash{webTopic}   = shift @$data;
        $fhash{extra}      = shift @$data;
        $fhash{remoteAddr} = shift @$data;
    }
    elsif ( $level =~ m/warning|error|critical|alert|emergency|notice/ ) {
        $fhash{epoch} = shift @$data;
        $fhash{extra} = join( ' ', @$data );
    }
    elsif ( $level eq 'debug' ) {
        $fhash{epoch} = shift @$data;
        $fhash{extra} = join( ' ', @$data );
    }
    return \%fhash,

      (
        [
            $fhash{epoch},
            $fhash{user}       || '',
            $fhash{action}     || '',
            $fhash{webTopic}   || '',
            $fhash{extra}      || '',
            $fhash{remoteAddr} || '',
            $fhash{level}
        ]
      );
}

1;

__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit, GeorgeClark, MichaelDaum

Copyright (C) 2012 SvenDowideit@fosiki.com

Copyright (C) 2012-2018  Foswiki Contributors.

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
