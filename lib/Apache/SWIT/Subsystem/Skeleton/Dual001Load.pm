use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Dual001Load;
use base 'Apache::SWIT::Maker::Skeleton::Dual001Load';

sub template { return <<'ENDS' };
use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;

BEGIN {
	use_ok('T::Test');
	use_ok('T::[% root_class_v %]');
};

my $t = T::Test->new;
$t->ok_ht_index_r(make_url => 1, ht => { first => '' });
ENDS

1;
