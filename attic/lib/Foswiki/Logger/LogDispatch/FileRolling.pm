# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::FileRolling;

use strict;
use warnings;

use Assert;
use Fcntl qw(:flock);
use Log::Dispatch ();
use Foswiki       ();
use Foswiki::Time qw(-nofoswiki);
use Foswiki::ListIterator                       ();
use Foswiki::AggregateIterator                  ();
use Foswiki::Logger::LogDispatch::FileUtil      ();
use Foswiki::Logger::LogDispatch::EventIterator ();

use Foswiki::Logger::LogDispatch::Base ();

our @ISA = qw/Foswiki::Logger::LogDispatch::Base/;

=begin TML

---+ package Foswiki::Logger::LogDispatch::FileRolling

use Log::Dispatch to allow logging to almost anything.

=cut

# Local symbol used so we can override it during unit testing
sub _time { return time() }

use constant TRACE => 0;

=begin TML

---++ ObjectMethod init()

called when this logger is enabled

=cut

sub init {
    my $this = shift;

    my %fileLevels;
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} ) {
        %fileLevels =
          %{ $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} };
    }
    else {
        %fileLevels = (
            debug  => 'debug:debug',
            events => 'info:info',
            error  => 'notice:emergency',
        );
    }

    $this->{fileLevels} = \%fileLevels;

    eval 'require Log::Log4perl::DateFormat';
    if ($@) {
        print STDERR
"ERROR: Log::Log4Perl missing - Log::Dispatch::File::Rolling DISABLED\n$@";
        $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
        return;
    }

    eval 'use Log::Dispatch::File::Rolling';
    if ($@) {
        print STDERR
          "ERROR: Log::Dispatch::File::Rolling missing - DISABLED\n$@";
        $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
        return;
    }

    my $pattern = $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern}
      || '-%d{yyyy-MM}.log';

    foreach my $file ( keys %fileLevels ) {
        my ( $min_level, $max_level ) =
          split( /:/, $fileLevels{$file} );
        print STDERR "File::Rolling: Adding $file as $min_level-$max_level\n"
          if TRACE;
        $this->{logd}->{dispatch}->add(
            Log::Dispatch::File::Rolling->new(
                name      => 'rolling-' . $file,
                min_level => $min_level,
                max_level => $max_level,
                filename  => $this->logDir . "/$file$pattern",
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

=begin TML

---++ ObjectMethod eachEventSince()

Determine the file needed to provide the requested event level, and return an iterator for the file.

=cut

sub eachEventSince {
    my ( $this, $time, $level, $lock ) = @_;

    my @logs;
    my $log = $this->getLogForLevel($level);

    my $prefix;
    my $pattern;
    my $postfix;

    my $supportedPattern = 1;

    my $cfgPattern = $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern}
      || '-%d{yyyy-MM}.log';

  # We will support a subset of the log filename patterns for the Rolling logger
  # y - Year
  # M - Month
  # d - Day in month
  # D - Day in year

    if ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} ) {
        if ( $cfgPattern =~ /^(.*)\%d\{([^\}]*)\}(.*)$/ ) {
            $prefix  = $1;
            $pattern = $2;
            $postfix = $3;
        }

        if ( !defined $pattern || $pattern =~ m/(?<!')[ehHmsSEFwWakKzZ]/ ) {
            $pattern = '';
            print STDERR
"Pattern $pattern contains unsupported characters, eachEventSince is not supported\n"
              if TRACE;
            $supportedPattern = 0;
        }
        if ( !$pattern =~ m/(?<!')[dDMy]+/ ) {
            print STDERR
"Pattern $pattern does not contain any tokens that can be incremented. eachEventSince is not supported\n"
              if TRACE;
            $supportedPattern = 0;
        }

        my $incr =
            $pattern =~ /(?<!')[dD]{1,3}/ ? 'P1d'
          : $pattern =~ /(?<!')MM/        ? 'P1m1d'
          : $pattern =~ /(?<!')y{1,4}/    ? 'P1y'
          :                                 '';

        my $endincr;
        my $enddate = Foswiki::Time::formatTime( _time(), 'iso', 'servertime' );
        ( $enddate, $endincr ) =
          Foswiki::Time::parseInterval( $enddate . '/' . $incr );

        my $logtime = $time;
        require Log::Log4perl::DateFormat;
        my $formatted = Log::Log4perl::DateFormat->new($pattern);

        while ( $logtime <= $endincr ) {
            my $firstDate =
              Foswiki::Time::formatTime( $logtime, 'iso', 'servertime' );
            my $interval = $firstDate . '/' . $incr;
            my ( $epoch, $epincr ) = Foswiki::Time::parseInterval($interval);

            my $filesfx = _format( $formatted, $epoch );

            my $logfile = $log;
            $logfile =~ s/\.log$/$prefix$filesfx$postfix/;

            if ( -f $logfile ) {
                print STDERR "Pushed $logfile\n" if TRACE;
                push( @logs, $logfile );
            }

            $logtime = $epincr;
        }
    }

    my @iterators;
    foreach my $logfile (@logs) {
        next unless -r $logfile;
        my $fh;
        if ( open( $fh, '<:encoding(utf-8)', $logfile ) ) {
            my $logIt =
              new Foswiki::Logger::LogDispatch::EventIterator( $fh,
                $time, $level );
            push( @iterators, $logIt );
            if ($lock) {
                $logIt->{logLocked} =
                  eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
            }
        }
        else {

            # Would be nice to report this, but it's chicken and egg and
            # besides, empty logfiles can happen.
            print STDERR "Failed to open $logfile: $!" if (TRACE);
        }
    }

    return new Foswiki::ListIterator( \@iterators ) if scalar(@iterators) == 0;
    return $iterators[0] if scalar(@iterators) == 1;
    return new Foswiki::AggregateIterator( \@iterators );

}

sub _format {
    my $formatted = shift;
    my $time      = shift;
    my $result    = $formatted->format( $time, 0 );
    $result =~ s/(\$+)/sprintf('%0'.length($1).'.'.length($1).'u', $$)/eg;
    return $result;

}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2020 SvenDowideit@fosiki.com, Foswiki Contributors.

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
