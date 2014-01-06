# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::Screen;

use strict;
use warnings;
use utf8;
use Assert;

=begin TML

---+ package Foswiki::Logger::LogDispatch::Screen

use Log::Dispatch to allow logging to almost anything.

=cut

use Log::Dispatch;
use Foswiki::Time                               ();
use Foswiki::ListIterator                       ();
use Foswiki::Configure::Load                    ();
use Foswiki::Logger::LogDispatch::EventIterator ();

sub new {
    my $class   = shift;
    my $logd    = shift;
    my $log     = $logd->{dispatch};
    my $binmode = $logd->{binmode};

    unless ( defined $Foswiki::cfg{Log}{LogDispatch}{Screen}{Layout} ) {
        $Foswiki::cfg{Log}{LogDispatch}{Screen}{Layout} = {
            info => [
                ' | ', [ ' ', 'timestamp', 'level' ],
                'user', 'action',
                'webTopic', [ ' ', 'extra', 'agent', ],
                'remoteAddr'
            ],
            DEFAULT => [
                ' | ',
                [ ' ', 'timestamp', 'level' ],
                [ ' ', 'caller',    'extra' ]
            ],
        };
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
                newline   => 1,
                callbacks => \&_flattenLog,
            )
        );
    }

    return bless( {}, $class );
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
      ( defined $Foswiki::cfg{Log}{LogDispatch}{Screen}{Layout}{$level} )
      ? $Foswiki::cfg{Log}{LogDispatch}{Screen}{Layout}{$level}
      : $Foswiki::cfg{Log}{LogDispatch}{Screen}{Layout}{DEFAULT};

    push @_, _Layout_ref => $logLayout_ref;

    goto &Foswiki::Logger::LogDispatch::_flattenLog;
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
