use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Scaffold::DualTest;
use base 'Apache::SWIT::Maker::Skeleton::Scaffold::DualTest';

sub template_prefix { return <<'ENDS'; }
use strict;
use warnings FATAL => 'all';

use Test::More tests => 17;
use Carp;

BEGIN {
	use_ok('T::Test');
	use_ok('T::[% root_class_v %]');
};
ENDS

1;
