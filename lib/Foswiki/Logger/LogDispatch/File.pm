# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::File;

use strict;
use warnings;
use utf8;
use Assert;

=begin TML

---+ package Foswiki::Logger::LogDispatch::File

use Log::Dispatch to allow logging to almost anything.

=cut

use Log::Dispatch                               ();
use Foswiki::ListIterator                       ();
use Foswiki::Configure::Load                    ();
use Foswiki::Logger::LogDispatch::EventIterator ();

# Local symbol used so we can override it during unit testing
sub _time { return time() }

use constant TRACE => 1;

sub new {
    my $class = shift;
    my $logd  = shift;

    my %FileRange;
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels} ) {
        %FileRange = %{ $Foswiki::cfg{Log}{LogDispatch}{File}{FileLevels} };
    }
    else {
        %FileRange = (
            debug  => 'debug:debug',
            events => 'info:info',
            error  => 'notice:emergency',
        );
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} ) {
        use Log::Dispatch::File;

        foreach my $file ( keys %FileRange ) {
            my ( $min_level, $max_level ) = split( /:/, $FileRange{$file} );
            print STDERR "File: Adding $file as $min_level-$max_level\n"
              if TRACE;
            $logd->{dispatch}->add(
                Log::Dispatch::File->new(
                    name      => 'file-' . $file,
                    min_level => $min_level,
                    max_level => $max_level,
                    filename  => "$Foswiki::cfg{Log}{Dir}/$file.log",
                    mode      => '>>',
                    binmode   => $logd->binmode(),
                    newline   => 1,
                    callbacks => \&Foswiki::Logger::LogDispatch::_flattenLog,
                )
            );
        }
    }

    return bless( { fileMap => \%FileRange }, $class );
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

    undef $this->{fileMap};

}

sub eachEventSince() {
    my ( $this, $time, $level ) = @_;

    my @logs;
    my $log =
      Foswiki::Logger::LogDispatch::FileUtil::getLogForLevel( $this, $level );
    my @iterators;

    unless ( -r $log ) {
        require Foswiki::ListIterator;
        return new Foswiki::ListIterator( [] );
    }

    my $fh;
    if ( open( $fh, '<', $log ) ) {
        push( @iterators,
            new Foswiki::Logger::LogDispatch::EventIterator( $fh, $time,
                $level ) );
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

# Get the name of the log for a given reporting level
sub getLogForLevel {
    my $logger = shift;
    my $level  = shift;
    my $file;

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
    foreach my $testfile ( keys %{ $logger->{fileMap} } ) {
        my ( $min_level, $max_level ) =
          split( /:/, $logger->{fileMap}->{$testfile} );
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
