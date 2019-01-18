# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::FileRotate;

use strict;
use warnings;

use constant TRACE => 0;

use Foswiki::Logger::LogDispatch::EventIterator ();
use Foswiki::Logger::LogDispatch::Base          ();

our @ISA = qw/Foswiki::Logger::LogDispatch::Base/;

our %RECURRENCE = (
    "yearly"  => "yyyy",
    "monthly" => "yyyy-MM",
    "weekly"  => "yyyy-ww",
    "daily"   => "yyyy-MM-dd",
    "hourly"  => "yyyy-MM-dd-HH",
);

=begin TML

---++ ObjectMethod init()

called when this logger is enabled

=cut

sub init {
    my $this = shift;

    my %fileLevels;
    if ( defined $Foswiki::cfg{Log}{LogDispatch}{FileRotate}{FileLevels} ) {
        %fileLevels =
          %{ $Foswiki::cfg{Log}{LogDispatch}{FileRotate}{FileLevels} };
    }
    else {
        %fileLevels = (
            debug  => 'debug:debug',
            events => 'info:info',
            error  => 'notice:emergency',
        );
    }

    $this->{fileLevels} = \%fileLevels;

    require Foswiki::Logger::LogDispatch::FileRotateFiltered;

    my $rec =
      $Foswiki::cfg{Log}{LogDispatch}{FileRotate}{Recurrence} || 'monthly';

    my $pattern = $RECURRENCE{$rec} || 'yyyy-MM';

    $this->{maxFiles} =
      $Foswiki::cfg{Log}{LogDispatch}{FileRotate}{MaxFiles} || 12;

    foreach my $file ( keys %fileLevels ) {
        my ( $min_level, $max_level, $filter ) =
          split( /:/, $fileLevels{$file}, 3 );

        print STDERR
          "FileRotate: Adding $file as $min_level-$max_level, filter="
          . ( $filter // 'undef' ) . "\n"
          if TRACE;

        $this->{logd}->{dispatch}->add(
            Foswiki::Logger::LogDispatch::FileRotateFiltered->new(
                name        => 'rotate-' . $file,
                min_level   => $min_level,
                max_level   => $max_level,
                filename    => $this->logDir . "/$file.log",
                DatePattern => $pattern,
                max         => $this->{maxFiles},
                mode        => '>>',
                binmode     => ":encoding(utf-8)",
                newline     => 1,
                filter      => $filter,
                callbacks   => sub {
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

    my $eventIter =
      Foswiki::Logger::LogDispatch::EventIterator->new( $time, $level, $lock );

    my $basename = $this->getLogForLevel($level);
    my $idx      = $this->{maxFiles} - 1;

    while ( $idx >= 0 ) {
        my $logFile = $basename;
        $logFile .= ".$idx" if $idx;
        $eventIter->addLogFile($logFile);
        $idx--;
    }

    return $eventIter;
}

1;

__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2019  Foswiki Contributors

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
