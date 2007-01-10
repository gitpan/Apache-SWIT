use strict;
use warnings FATAL => 'all';

package T::ValidateFailure::Root;
use base 'HTML::Tested';

sub ht_validate { return qw(hoho); }

package T::ValidateFailure;
use base 'Apache::SWIT::HTPage';
use File::Slurp;

sub ht_swit_update {
	my ($class, $r) = @_;
	write_file($ENV{SWIT_TEST_DIR} . "/a", "");
	return "r";
}

1;
