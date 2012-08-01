package LogDispatchContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'LogDispatchContribSuite' }

sub include_tests { qw(LogDispatchContribTests) }

1;
