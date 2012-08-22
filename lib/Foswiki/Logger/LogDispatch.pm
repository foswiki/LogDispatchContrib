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
    return
      bless( { logger => $log, binmode => $binmode, fileMap => \%FileRange },
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

    #$this->{logger}->finish() if $this->{logger};
    undef $this->{logger};
    undef $this->{binmode};
    undef $this->{filemap};

}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my ( $this, $level, @fields ) = @_;

    if (TRACE) {
        foreach my $field (@_) {
            print STDERR "field $field \n";
        }
    }

    my $now = _time();
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift( @fields, "$time $level" );

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

This logger implementation maps groups of levels to a single logfile, viz.  By default:
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
   * =debug= messages are output together.
The actual groupings are configurable.

=cut

sub eachEventSince {
    my ( $this, $time, $level ) = @_;

  # We will support a subset of the log filename patterns for the Rolling logger
  # y - Year
  # M - Month (2 digit only)
  # d - Day in month
  # D - Day in year

    my $prefix           = '';
    my $pattern          = '';
    my $postfix          = '';
    my $supportedPattern = 0;

    if ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} ) {
        if ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern} =~
            /^(.*)\%d\{([^\}]*)\}(.*)$/ )
        {
            $prefix           = $1;
            $pattern          = $2;
            $postfix          = $3;
            $supportedPattern = 1;

            if ( !defined $pattern || $pattern =~ m/(?<!')[ehHmsSEFwWakKzZ]/ ) {
                $pattern = '';
                print STDERR
"Pattern $pattern contains unsupported characters, eachEventSince is not supported\n"
                  if TRACE;
                $supportedPattern = 0;
            }

        }
    }

    print STDERR "Pattern $pattern supported = $supportedPattern\n" if TRACE;

    my @logs;
    my $log = $this->_getLogForLevel($level);

    if (   $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled}
        && $supportedPattern )
    {

        my $incr =
            $pattern =~ /(?<!')[dD]{1,3}/ ? 'P1d'
          : $pattern =~ /(?<!')MM/        ? 'P1m1d'
          : $pattern =~ /(?<!')y{1,4}/    ? 'P1y'
          :                                 '';

        my $now     = _time();
        my $logtime = $time;

        while ( $logtime <= $now ) {
            my $firstDate =
              Foswiki::Time::formatTime( $logtime, 'iso', 'gmtime' );
            my $interval = $firstDate . '/' . $incr;
            my ( $epoch, $epincr ) = Foswiki::Time::parseInterval($interval);

            require Log::Log4perl::DateFormat;
            my $formatted = Log::Log4perl::DateFormat->new($pattern);
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
    elsif ( $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} ) {
        push( @logs, $log );
    }
    else {
        Foswiki::Func::writeWarning(
"eachEventSince not supported for chosen log methods.  File or FileRolling should be enabled."
        );
        require Foswiki::ListIterator;
        return new Foswiki::ListIterator( [] );
    }

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
    my $this  = shift;
    my $level = shift;
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
    foreach my $testfile ( keys %{ $this->{fileMap} } ) {
        my ( $min_level, $max_level ) =
          split( /:/, $this->{fileMap}->{$testfile} );
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
