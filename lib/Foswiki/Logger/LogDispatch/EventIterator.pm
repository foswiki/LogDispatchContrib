# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::EventIterator;

use strict;
use warnings;
use Assert;
use Fcntl qw(:flock);
use Foswiki::Time qw(-nofoswiki);

# Private subclass of LineIterator that splits events into fields
require Foswiki::LineIterator;
@Foswiki::Logger::LogDispatch::EventIterator::ISA = ('Foswiki::LineIterator');

sub new {
    my ( $class, $fh, $threshold, $level ) = @_;
    my $this = $class->SUPER::new($fh);
    $this->{_threshold} = $threshold;
    $this->{_level}     = $level;
    return $this;
}

sub hasNext {
    my $this = shift;
    return 1 if defined $this->{_nextEvent};
    while ( $this->SUPER::hasNext() ) {
        my $ln = $this->SUPER::next();
        $ln =~ s/&#255;&#10;/\n/g;    # Reverse newline encoding

        #SMELL: This whole process needs to reverse the record as defined
        #       in LogDispatch::flattenLog and the configuration.
        my @line = split( /\s*\|\s*/, $ln );
        shift @line;    # skip the leading empty cell
        next unless scalar(@line) && defined $line[0];
        if (
            $line[0] =~ s/\s+$this->{_level}\s*$//    # test the level
              # accept a plain 'old' format date with no level only if reading info (statistics)
            || $line[0] =~ /^\d{1,2} [a-z]{3} \d{4}/i
            && $this->{_level} eq 'info'
          )
        {
            $line[0] = Foswiki::Time::parseTime( $line[0] );
            next
              unless ( defined $line[0] ); # Skip record if time doesn't decode.
            if ( $line[0] >= $this->{_threshold} ) {    # test the time
                $this->{_nextEvent} = \@line;
                return 1;
            }
        }
    }
    return 0;
}

sub next {
    my $this = shift;
    my ( $fhash, $data ) = $this->parseRecord();

    #use Data::Dumper;
    #print STDERR '_nextEvent ' . Data::Dumper::Dumper( \$this->{_nextEvent} ) .
    #             '$fhash ' . Data::Dumper::Dumper( \$fhash ) .
    #             '$data ' . Data::Dumper::Dumper( \$data ) .
    #             "\n";

    undef $this->{_nextEvent};
    return $data;
}

sub parseRecord {
    my $this = shift;

    my $level = $this->{_level};        # Level parsed from record or assumed.
    my $data  = $this->{_nextEvent};    # Array ref of raw fields from record.
    my %fhash;                          # returned hash of identified fields
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

Author: SvenDowideit, GeorgeClark

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
