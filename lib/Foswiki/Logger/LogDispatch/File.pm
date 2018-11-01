# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::File;

use strict;
use warnings;

use constant TRACE => 0;

use Fcntl qw(:flock);
use Log::Dispatch              ();
use Foswiki::AggregateIterator ();
use Foswiki::ListIterator      ();

use Foswiki::Logger::LogDispatch::Base ();

our @ISA = qw/Foswiki::Logger::LogDispatch::Base/;

=begin TML

---++ ObjectMethod init()

called when this logger is enabled

=cut

sub init {
    my $this = shift;

    my %fileLevels;
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels} ) {
        %fileLevels = %{ $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels} };
    }
    else {
        %fileLevels = (
            debug  => 'debug:debug',
            events => 'info:info',
            error  => 'notice:emergency',
        );
    }

    $this->{fileLevels} = \%fileLevels;

    foreach my $file ( keys %fileLevels ) {
        my ( $min_level, $max_level, $filter ) =
          split( /:/, $fileLevels{$file}, 3 );

        if ($filter) {
            require Foswiki::Logger::LogDispatch::FileFiltered;
            print STDERR
              "File: Adding Filtered $file as $min_level-$max_level, $filter\n"
              if TRACE;
            $this->{logd}->{dispatch}->add(
                Foswiki::Logger::LogDispatch::FileFiltered->new(
                    name      => 'file-' . $file,
                    min_level => $min_level,
                    max_level => $max_level,
                    filename  => $this->logDir . "$file.log",
                    mode      => '>>',
                    binmode   => ":encoding(utf-8)",
                    newline   => 1,
                    filter    => $filter,
                    callbacks => sub {
                        return $this->flattenLog(@_);
                    }
                )
            );
        }
        else {
            require Log::Dispatch::File;
            print STDERR "File: Adding $file as $min_level-$max_level\n"
              if TRACE;
            $this->{logd}->{dispatch}->add(
                Log::Dispatch::File->new(
                    name      => 'file-' . $file,
                    min_level => $min_level,
                    max_level => $max_level,
                    filename  => $this->logDir . "/$file.log",
                    mode      => '>>',
                    binmode   => ":encoding(utf-8)",
                    newline   => 1,
                    callbacks => sub {
                        return $this->flattenLog(@_);
                    }
                )
            );
        }
    }

    return $this;
}

=begin TML

---++ ObjectMethod eachEventSince()

Determine the file needed to provide the requested event level, and return an iterator for the file.

=cut

sub eachEventSince {
    my ( $this, $time, $level, $lock ) = @_;

    my @logs;
    my $log = $this->getLogForLevel($level);
    my @iterators;

    unless ( -r $log ) {
        require Foswiki::ListIterator;
        return new Foswiki::ListIterator( [] );
    }

    my $fh;
    if ( open( $fh, '<:encoding(utf-8)', $log ) ) {
        my $logIt =
          new Foswiki::Logger::LogDispatch::File::EventIterator( $fh, $time,
            $level );
        push( @iterators, $logIt );
        if ($lock) {
            $logIt->{logLocked} =
              eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
        }
    }
    else {

        # Would be nice to report this, but it's chicken and egg and
        # besides, empty logfiles can happen.
        print STDERR "Failed to open $log: $!" if (TRACE);
    }

    return new Foswiki::ListIterator( \@iterators ) if scalar(@iterators) == 0;
    return $iterators[0] if scalar(@iterators) == 1;
    return new Foswiki::AggregateIterator( \@iterators );

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
