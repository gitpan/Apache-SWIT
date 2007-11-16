use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::ValidateFailure');
};

unlink "/tmp/apache_swit_validate_failure";

$ENV{SWIT_HAS_APACHE} = 0;
Apache::SWIT::Test->make_aliases(validate_fail => 'T::ValidateFailure');

my $t = Apache::SWIT::Test->new;
eval { $t->ht_validate_fail_u(ht => {}); };
like($@, qr/ht_validate failed/); 
like($@, qr/Request/);
is(-f "/tmp/apache_swit_validate_failure", undef);

eval { $t->ht_validate_fail_r(ht => {}); };
like($@, qr/Request/);
like($@, qr/uninitialized/);
