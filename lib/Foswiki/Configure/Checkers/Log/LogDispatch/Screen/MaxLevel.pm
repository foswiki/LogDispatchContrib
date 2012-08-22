# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::LogDispatch::Screen::MaxLevel;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency;

my $prefix;
my $postfix;
my $formatted;

sub check {
    my $this = shift;
    my $e    = '';

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

    my $min_level = $Foswiki::cfg{Log}{LogDispatch}{Screen}{MinLevel};
    my $max_level = $Foswiki::cfg{Log}{LogDispatch}{Screen}{MaxLevel};

    if ( defined $min_level && defined $max_level ) {
        $e .= $this->ERROR(
"Minimum level <code>$min_level ($level2num{$min_level})</code> is not less than or equal to Maximum level:  <code>$max_level ($level2num{$max_level})</code>"
        ) unless ( $level2num{$min_level} le $level2num{$max_level} );
    }

    return $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
