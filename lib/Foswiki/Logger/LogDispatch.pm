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

use Foswiki::Configure::Load ();

# Local symbol used so we can override it during unit testing
sub _time { return time() }

sub new {
    my $class = shift;
    my $log   = Log::Dispatch->new();

    if ( $Foswiki::cfg{Log}{LogDispatch}{File}{Enabled} ) {
        use Log::Dispatch::File;
        $log->add(
            Log::Dispatch::File->new(
                name      => 'file',
                min_level => 'info',
                filename  => 'Somefile.log',
                mode      => '>>',
                newline   => 1
            )
        );
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{Screen}{Enabled} ) {
        use Log::Dispatch::Screen;
        $log->add(
            Log::Dispatch::Screen->new(
                name      => 'screen',
                min_level => 'info',
                stderr    => 1,
                newline   => 1
            )
        );
    }

    if ( $Foswiki::cfg{Log}{LogDispatch}{Syslog}{Enabled} ) {
        use Log::Dispatch::Syslog;
        $log->add(
            Log::Dispatch::Syslog->new(
                name      => 'syslog',
                min_level => 'info',
                stderr    => 1,
                newline   => 1,
                ident     => 'Foswiki'
            )
        );
    }
    return bless( { logger => $log }, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my ( $this, $level, @fields ) = @_;

    my $message =
      '| ' . join( ' | ', map { s/\|/&vbar;/g; $_ } @fields ) . ' |';

    my $file;
    my $mode = '>>';

    # Item10764, SMELL UNICODE: actually, perhaps we should open the stream this
    # way for any encoding, not just utf8. Babar says: check what Catalyst does.
    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        $mode .= ":encoding($Foswiki::cfg{Site}{CharSet})";
    }
    elsif ( utf8::is_utf8($message) ) {
        require Encode;
        $message = Encode::encode( $Foswiki::cfg{Site}{CharSet}, $message, 0 );
    }

    #TODO: make configure UI and don't log to everywhere at once.

    $this->{logger}->log( level => $level, message => $message );

    #    if ( $level =~ /^(error|critical|alert|emergency)$/ ) {
    #        print STDERR "$message\n";
    #    }
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
