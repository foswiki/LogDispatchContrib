# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::LogDispatch::FileRolling::Pattern;

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

    my $n = $this->checkPerlModule( 'Log::Log4perl',
        'Required to use FileRolling logging' );
    unless ( $n =~ m/Not installed/ ) {

        return $e
          unless defined $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern};

        if ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern} =~
            /\%d\{.*?\$.*?\}/ )
        {
            $e .= $this->WARN(
"Filename pattern containg the PID cannot be processed by Statistics or other users of the eachEventSince() function"
            );
        }

        if ( $Foswiki::cfg{Log}{LogDispatch}{FileRolling}{Pattern} =~
            /^(.*)\%d\{([^\}]*)\}(.*)$/ )
        {
            $prefix  = $1;
            $postfix = $3;
            eval "require Log::Log4perl::DateFormat";
            return $this->ERROR(
                "Required module Log::Log4perl::DateFormat missing.")
              if $@;
            $formatted = Log::Log4perl::DateFormat->new($2);
            my $filename = $prefix . _format() . $postfix;
            $e .= $this->NOTE("Example filename: <code>events$filename</code>");
            if ( $filename =~ m/not\s?(\(yet\))?\s?implemented/ ) {
                $e .= $this->ERROR("Unsupported characters in pattern");
            }
        }
    }

    return $e;
}

sub _format {
    my $result = $formatted->format( time(), 0 );
    $result =~ s/(\$+)/sprintf('%0'.length($1).'.'.length($1).'u', $$)/eg;
    return $result;

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
