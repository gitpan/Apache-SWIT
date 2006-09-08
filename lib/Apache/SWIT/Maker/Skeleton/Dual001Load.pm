use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Dual001Load;
use base 'Apache::SWIT::Maker::Skeleton';

sub output_file { return 't/dual/001_load.t'; }
sub template { return <<'ENDS' };
use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;

BEGIN {
	use_ok('T::Test');
	use_ok('[% root_class_v %]::UI::Index');
};

my $t = T::Test->new;
$t->ok_ht_index_r(make_url => 1, ht => { first => '' });
$t->ok_ht_index_r(base_url => '/', ht => { first => '' });
$t->ok_get('www/main.css');
$t->content_like(qr/CSS/);
ENDS

1;
