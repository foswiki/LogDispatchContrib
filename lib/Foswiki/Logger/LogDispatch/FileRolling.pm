# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::FileRolling::EventIterator;
use strict;
use warnings;
use utf8;
use Assert;

use Fcntl qw(:flock);

# Internal class for Logfile iterators.
# So we don't break encapsulation of file handles.  Open / Close in same file.
our @ISA = qw/Foswiki::Logger::LogDispatch::EventIterator/;

# # Object destruction
# # Release locks and file
sub DESTROY {
    my $this = shift;
    flock( $this->{handle}, LOCK_UN )
      if ( defined $this->{logLocked} );
    close( delete $this->{handle} ) if ( defined $this->{handle} );
}

package Foswiki::Logger::LogDispatch::FileRolling;

use strict;
use warnings;
use utf8;
use Assert;

=begin TML

---+ package Foswiki::Logger::LogDispatch::FileRolling

use Log::Dispatch to allow logging to almost anything.

=cut

use Fcntl qw(:flock);
use Log::Dispatch ();
use Foswiki       ();
use Foswiki::Time qw(-nofoswiki);
use Foswiki::ListIterator                       ();
use Foswiki::AggregateIterator                  ();
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
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} ) {
        %FileRange =
          %{ $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} };
    }
    else {
        %FileRange = (
            debug  => 'debug:debug',
            events => 'info:info',
            error  => 'notice:emergency',
        );
    }

    unless ( defined $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Layout} ) {
        $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Layout} = {
            info => [
                ' | ', [ ' ', 'timestamp', 'level' ],
                'user', 'action',
                'webTopic', [ ' ', 'extra', 'agent', '*' ],
                'remoteAddr'
            ],
            DEFAULT => [
                ' | ',
                [ ' ', 'timestamp', 'level' ],
                [ ' ', 'caller',    'extra' ]
            ],
        };
    }

    eval 'require Log::Log4perl::DateFormat';
    if ($@) {
        print STDERR
"ERROR: Log::Log4Perl missing - Log::Dispatch::File::Rolling DISABLED\n$@";
        $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
        return 0;
    }
    else {
        eval 'use Log::Dispatch::File::Rolling';
        if ($@) {
            print STDERR
              "ERROR: Log::Dispatch::File::Rolling missing - DISABLED\n$@";
            $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} = 0;
            return 0;
        }
        else {
            my $pattern = $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern}
              || '-%d{yyyy-MM}.log';

            foreach my $file ( keys %FileRange ) {
                my ( $min_level, $max_level ) =
                  split( /:/, $FileRange{$file} );
                print STDERR
                  "File::Rolling: Adding $file as $min_level-$max_level\n"
                  if TRACE;
                $logd->{dispatch}->add(
                    Log::Dispatch::File::Rolling->new(
                        name      => 'rolling-' . $file,
                        min_level => $min_level,
                        max_level => $max_level,
                        filename  => "$Foswiki::cfg{Log}{Dir}/$file$pattern",
                        mode      => '>>',
                        binmode   => $logd->binmode(),
                        newline   => 1,
                        callbacks => \&_flattenLog,
                    )
                );
            }
        }
    }

    return bless( { fileMap => \%FileRange }, $class );
}

=begin TML

---++ Private method _flattenLog()
Provides a default layout if configure neglected to include one for the File logger,
and then replaces the call using goto &Foswiki::Logger::LogDispatch::_flattenLog() utility routine.

=cut

sub _flattenLog {

    my $level = '';

# Benchmark shows it's 30% faster to scan the parameter array rather than convert it to a hash
    for ( my $e = 0 ; $e < scalar @_ ; $e += 2 ) {
        if ( $_[$e] eq 'level' ) {
            $level = $_[ $e + 1 ];
            last;
        }
    }

    my $logLayout_ref =
      ( defined $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Layout}{$level} )
      ? $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Layout}{$level}
      : $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Layout}{DEFAULT};

    push @_, _Layout_ref => $logLayout_ref;

    goto &Foswiki::Logger::LogDispatch::_flattenLog;
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
        my $enddate = Foswiki::Time::formatTime( _time(), 'iso', 'gmtime' );
        ( $enddate, $endincr ) =
          Foswiki::Time::parseInterval( $enddate . '/' . $incr );

        my $logtime = $time;
        require Log::Log4perl::DateFormat;
        my $formatted = Log::Log4perl::DateFormat->new($pattern);

        while ( $logtime <= $endincr ) {
            my $firstDate =
              Foswiki::Time::formatTime( $logtime, 'iso', 'gmtime' );
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
        if ( open( $fh, '<', $logfile ) ) {
            my $logIt =
              new Foswiki::Logger::LogDispatch::FileRolling::EventIterator( $fh,
                $time, $level );
            push( @iterators, $logIt );
            $logIt->{logLocked} =
              eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
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
