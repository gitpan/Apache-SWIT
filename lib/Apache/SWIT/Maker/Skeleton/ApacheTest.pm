use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::ApacheTest;
use base 'Apache::SWIT::Maker::Skeleton';

sub output_file { return 't/apache_test.pl'; }

sub template { return <<ENDM; }
use T::TempDB;
do "t/apache_test_run.pl";
ENDM

1;
