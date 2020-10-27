# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::LogDispatch::FileRolling::Enabled;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency;

sub check {
    my $this = shift;
    my $e    = '';

    my $n = $this->checkPerlModule( 'Log::Dispatch::File::Rolling',
        'Required to use FileRolling logging' );
    if ( $n =~ m/Not installed/ ) {
        $e .=
          ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} )
          ? $this->ERROR($n)
          : $this->NOTE($n);
    }
    else {
        $e .= $this->NOTE($n);
    }

    $n = $this->checkPerlModule( 'Log::Log4perl',
        'Required to use FileRolling logging' );
    if ( $n =~ m/Not installed/ ) {
        $e .=
          ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Enabled} )
          ? $this->ERROR($n)
          : $this->NOTE($n);
    }
    else {
        $e .= $this->NOTE($n);
    }
    return $e;
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2020 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
