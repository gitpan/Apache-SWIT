use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::ValidateFailure');
};

$ENV{SWIT_HAS_APACHE} = 0;
Apache::SWIT::Test->make_aliases(validate_fail => 'T::ValidateFailure');

my $t = Apache::SWIT::Test->new;
eval { $t->ht_validate_fail_u(ht => {}); };
like($@, qr/ht_validate failed/); 
is(-f $ENV{SWIT_TEST_DIR} . "/a", undef);

