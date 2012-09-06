# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::LogDispatch::FileRolling::FileLevels;

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

    return
      unless defined $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels};

    my %FileLevels =
      %{ $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{FileLevels} };

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

    foreach my $file ( keys %FileLevels ) {
        my ( $min_level, $max_level ) =
          split( /:/, $FileLevels{$file} );
        $e .= $this->ERROR(
"Invalid Minimum level <code>$min_level</code> for <code>$file</code>"
        ) unless ( defined $level2num{$min_level} );
        $e .= $this->ERROR(
"Invalid Maximum level <code>$max_level</code> for <code>$file</code>"
        ) unless ( defined $level2num{$max_level} );
        if ( defined $level2num{$min_level} && defined $level2num{$max_level} )
        {
            $e .= $this->ERROR(
"For file <code>$file</code>, <code>$min_level ($level2num{$min_level})</code> is not less than or equal to:  <code>$max_level ($level2num{$max_level})</code>"
            ) unless ( $level2num{$min_level} <= $level2num{$max_level} );
        }
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
