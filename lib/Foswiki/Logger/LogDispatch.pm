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
use Foswiki::Time            ();
use Foswiki::ListIterator    ();
use Foswiki::Configure::Load ();

# Local symbol used so we can override it during unit testing
sub _time { return time() }

use constant TRACE => 1;

sub new {
    my $class   = shift;
    my $log     = Log::Dispatch->new();
    my $binmode = '';
    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        $binmode .= ":encoding($Foswiki::cfg{Site}{CharSet})";
    }

    my %FileRange;
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{FileRange} ) {
        %FileRange = %{ $Foswiki::cfg{Log}{LogDispatch}{FileRange} };
    }
    else {
        %FileRange = (
            debug  => 'debug:debug',
            events => 'info:info',
            error  => 'notice:emergency',
        );
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} ) {
        eval 'use Log::Dispatch::File::Rolling';
        if ($@) {
            print STDERR "ERROR: Log::Dispatch::File::Rolling DISABLED\n$@";
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
                $log->add(
                    Log::Dispatch::File::Rolling->new(
                        name      => 'rolling-' . $file,
                        min_level => $min_level,
                        max_level => $max_level,
                        filename  => "$Foswiki::cfg{Log}{Dir}/$file$pattern",
                        mode      => '>>',
                        binmode   => $binmode,
                        newline   => 1
                    )
                );
            }
        }
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} ) {
        use Log::Dispatch::File;

        foreach my $file ( keys %FileRange ) {
            my ( $min_level, $max_level ) = split( /:/, $FileRange{$file} );
            print STDERR "File: Adding $file as $min_level-$max_level\n"
              if TRACE;
            $log->add(
                Log::Dispatch::File->new(
                    name      => 'file-' . $file,
                    min_level => $min_level,
                    max_level => $max_level,
                    filename  => "$Foswiki::cfg{Log}{Dir}/$file.log",
                    mode      => '>>',
                    binmode   => $binmode,
                    newline   => 1
                )
            );
        }
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled} ) {
        use Log::Dispatch::Screen;
        my $min_level = $Foswiki::cfg{Log}{LogDispatch}{Screen}{MinLevel}
          || 'error';
        my $max_level = $Foswiki::cfg{Log}{LogDispatch}{Screen}{MaxLevel}
          || 'emergency';
        $log->add(
            Log::Dispatch::Screen->new(
                name      => 'screen',
                min_level => $min_level,
                max_level => $max_level,
                stderr    => 1,
                newline   => 1
            )
        );
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{Syslog}{Enabled} ) {
        use Log::Dispatch::Syslog;
        my $ident = $Foswiki::cfg{Log}{LogDispatch}{Syslog}{Identifier}
          || 'Foswiki';
        my $facility = $Foswiki::cfg{Log}{LogDispatch}{Syslog}{Facility}
          || 'user';
        my $min_level = $Foswiki::cfg{Log}{LogDispatch}{Syslog}{MinLevel}
          || 'warn';
        my $max_level = $Foswiki::cfg{Log}{LogDispatch}{Syslog}{MaxLevel}
          || 'emergency';
        my $logopt = $Foswiki::cfg{Log}{LogDispatch}{Syslog}{Logopt}
          || 'ndelay,nofatal,pid';
        $log->add(
            Log::Dispatch::Syslog->new(
                name      => 'syslog',
                min_level => $min_level,
                max_level => $max_level,
                facility  => $facility,
                ident     => $ident,
                logopt    => $logopt,
            )
        );
    }
    return bless( { logger => $log, binmode => $binmode }, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my ( $this, $level, @fields ) = @_;

    my $now = _time();
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift( @fields, "$time $level" );
    my $message =
      '| ' . join( ' | ', map { s/\|/&vbar;/g; $_ } @fields ) . ' |';

    # Item10764, SMELL UNICODE: actually, perhaps we should open the stream this
    # way for any encoding, not just utf8. Babar says: check what Catalyst does.
    unless ( $this->{binmode} ) {
        if ( utf8::is_utf8($message) ) {
            require Encode;
            $message =
              Encode::encode( $Foswiki::cfg{Site}{CharSet}, $message, 0 );
        }
    }

    $this->{logger}->log( level => $level, message => $message );

}

{

    # Private subclass of LineIterator that splits events into fields
    package Foswiki::Logger::LogDispatch::EventIterator;
    require Foswiki::LineIterator;
    @Foswiki::Logger::LogDispatch::EventIterator::ISA =
      ('Foswiki::LineIterator');

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
            my @line = split( /\s*\|\s*/, $this->SUPER::next() );
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
                  unless ( defined $line[0] )
                  ;    # Skip record if time doesn't decode.
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
        my $data = $this->{_nextEvent};
        undef $this->{_nextEvent};
        return $data;
    }
}

=begin TML

---++ StaticMethod eachEventSince($time, $level) -> $iterator

See Foswiki::Logger for the interface.

Copied from Foswiki::PlainFile logger.

This logger implementation maps groups of levels to a single logfile, viz.
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
This method cannot 

=cut

sub eachEventSince {
    my ( $this, $time, $level ) = @_;
    my $log = _getLogForLevel($level);

    # Find the year-month for the current time
    my $now         = _time();
    my $nowLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $nowLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Find the year-month for the first time in the range
    my $logYear  = Foswiki::Time::formatTime( $time, '$year', 'servertime' );
    my $logMonth = Foswiki::Time::formatTime( $time, '$mo',   'servertime' );

    # Get the names of all the logfiles in the time range
    my @logs;
    while ( !( $logMonth == $nowLogMonth && $logYear == $nowLogYear ) ) {
        my $logfile = $log;
        my $logTime = $logYear . sprintf( "%02d", $logMonth );
        $logfile =~ s/\.log$/.$logTime/g;
        push( @logs, $logfile );
        $logMonth++;
        if ( $logMonth == 13 ) {
            $logMonth = 1;
            $logYear++;
        }
    }

    # Finally the current log
    push( @logs, $log );

    my @iterators;
    foreach my $logfile (@logs) {
        next unless -r $logfile;
        my $fh;
        if ( open( $fh, '<', $logfile ) ) {
            push(
                @iterators,
                new Foswiki::Logger::LogDispatch::EventIterator(
                    $fh, $time, $level
                )
            );
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
sub _getLogForLevel {
    my $level = shift;

    # Map from a log level to the root of a log file name
    my %FileMapping;
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{FileMapping} ) {
        %FileMapping = %{ $Foswiki::cfg{Log}{LogDispatch}{FileMapping} };
    }
    else {
        %FileMapping = (
            debug     => 'debug',     # 0
            info      => 'events',    # 1
            notice    => 'error',     # 2
            warning   => 'error',     # 3
            error     => 'error',     # 4
            critical  => 'error',     # 5
            alert     => 'error',     # 6
            emergency => 'error'      # 7
        );
    }

    ASSERT( defined $FileMapping{$level} ) if DEBUG;
    my $log = $Foswiki::cfg{Log}{Dir} . '/' . $FileMapping{$level} . '.log';

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

Copyright (C) 2012 SvenDowideit@fosiki.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
