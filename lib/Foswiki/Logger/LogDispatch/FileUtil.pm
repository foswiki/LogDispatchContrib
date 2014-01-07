# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::FileUtil;

use strict;
use warnings;
use utf8;
use Assert;

=begin TML

---+ package Foswiki::Logger::LogDispatch

use Log::Dispatch to allow logging to almost anything.

=cut

use Log::Dispatch;
use Foswiki::Time qw(-nofoswiki);
use Foswiki::ListIterator    ();
use Foswiki::Configure::Load ();

# Local symbol used so we can override it during unit testing
sub _time { return time() }

use constant TRACE => 0;

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

sub patternSupported() {

  # We will support a subset of the log filename patterns for the Rolling logger
  # y - Year
  # M - Month
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
            if ( !$pattern =~ m/(?<!')[dDMy]+/ ) {
                print STDERR
"Pattern $pattern does not contain any tokens that can be incremented. eachEventSince is not supported\n"
                  if TRACE;
                $supportedPattern = 0;
            }
        }
    }

    print STDERR "Pattern $pattern supported = $supportedPattern\n" if TRACE;
    return ( $supportedPattern, $prefix, $pattern, $postfix );
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
