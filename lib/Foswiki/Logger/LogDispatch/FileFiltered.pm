# See bottom of file for license and copyright information
package Foswiki::Logger::LogDispatch::FileFiltered;

use strict;
use warnings;

use Log::Dispatch::File ();
our @ISA = ('Log::Dispatch::File');

sub new {
    my $class = shift;
    my %p     = @_;

    my $self = $class->SUPER::new(@_);
    $self->{filter} = $p{filter};

    return $self;
}

sub log_message {
    my $self = shift;
    my %p    = @_;

    return
      if ( defined $self->{filter} && $p{message} !~ qr/$self->{filter}/ );

    $self->SUPER::log_message(@_);
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2020 Foswiki Contributors.
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

