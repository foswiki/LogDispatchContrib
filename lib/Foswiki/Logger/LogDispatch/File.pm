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
use Foswiki::Logger::LogDispatch::FileUtil      ();
use Foswiki::Logger::LogDispatch::EventIterator ();

# Local symbol used so we can override it during unit testing
sub _time { return time() }

use constant TRACE => 0;

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
        my $hasFilter = 0;

        foreach my $file ( keys %FileRange ) {
            my ( $min_level, $max_level, $filter ) =
              split( /:/, $FileRange{$file}, 3 );
            if ($filter) {
                $hasFilter = 1;
                next;
            }
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
        my $enstr = ($hasFilter) ? "ENABLED\n" : "DISABLED\n";
        print STDERR "Filtered logging will be $enstr" if TRACE;
        undef *Foswiki::Logger::LogDispatch::File::log unless ($hasFilter);
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

=begin TML

---++ ObjectMethod log()
This method is only called if a filter has been specified in the File map.  Log::Dispatch
does not provide a way to filter messages, so this routine determines if the filter matches
the log record, adds the log method just for this record, calls the log_to function directly
and then removes the method.

=cut

sub log {
    use Data::Dumper;
    print STDERR "LOG CALLED: " . Data::Dumper->Dumper( $_[1] ) . "\n" if TRACE;

    my $this  = shift;
    my $fhash = shift;

    my $message = Foswiki::Logger::LogDispatch::_flattenLog(%$fhash);
    ($message) = $message =~ m/(.*)/;    #untaint

    foreach my $file ( keys %{ $this->{fileMap} } ) {
        my ( $min_level, $max_level, $filter ) =
          split( /:/, $this->{fileMap}->{$file}, 3 );
        if ( $filter && $message =~ qr/$filter/ ) {
            print STDERR
              "File: Adding $file as $min_level-$max_level filter $filter\n"
              if TRACE;
            $fhash->{logd}->{dispatch}->add(
                Log::Dispatch::File->new(
                    name              => 'file-' . $file,
                    min_level         => $min_level,
                    max_level         => $max_level,
                    filename          => "$Foswiki::cfg{Log}{Dir}/$file.log",
                    mode              => '>>',
                    binmode           => $fhash->{logd}->binmode(),
                    newline           => 1,
                    close_after_write => 1,
                )
            );

            $fhash->{logd}->{dispatch}->log_to(
                name    => "file-$file",
                level   => $fhash->{level},
                message => "$message"
            );
            $fhash->{logd}->{dispatch}->remove("file-$file");
        }
    }

}

=begin TML

---++ ObjectMethod eachEventSince()
Determine the file needed to provide the requested event level, and return an iterator for the file.

=cut

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

=begin TML

---++ ObjectMethod getLogForLevel()
Called with a requested level, it processes reverses the file map to return the log name
prefix that should contain the requested messages.

Filtered files are not included. 

=cut

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
    foreach ( keys %{ $logger->{fileMap} } ) {
        my ( $min_level, $max_level, $filter ) =
          split( /:/, $logger->{fileMap}->{$_} );
        if (   $level2num{$min_level} <= $level2num{$level}
            && $level2num{$max_level} >= $level2num{$level} )
        {
            $file = $_;
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
