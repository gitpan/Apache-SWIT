use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use Apache::SWIT::Session;

BEGIN { use_ok('T::Test');
	use_ok('T::ValidateFailure');
};

unlink "/tmp/apache_swit_validate_failure";

$ENV{SWIT_HAS_APACHE} = 0;
T::Test->make_aliases(validate_fail => 'T::ValidateFailure');

my $t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
eval { $t->ht_validate_fail_u(ht => {}); };
like($@, qr/ht_validate failed/); 
like($@, qr/Request/);
is(-f "/tmp/apache_swit_validate_failure", undef);

eval { $t->ht_validate_fail_r(ht => {}); };
like($@, qr/Request/);
like($@, qr/uninitialized/);
