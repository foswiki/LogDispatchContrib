# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::Syslog;

use strict;
use warnings;
use utf8;
use Assert;

=begin TML

---+ package Foswiki::Logger::LogDispatch::File

use Log::Dispatch to allow logging to almost anything.

=cut

use Log::Dispatch;

sub new {
    my $class   = shift;
    my $logd    = shift;
    my $log     = $logd->{dispatch};
    my $binmode = $logd->{binmode};

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
                callbacks => \&Foswiki::Logger::LogDispatch::_flattenLog,
            )
        );
    }

    return bless( {}, $class );
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
