use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::Redirect');
};

Apache::SWIT::Test->make_aliases(redirect => 'T::Redirect');

my $t = Apache::SWIT::Test->new;
$t->root_location('/test');
$t->redirect_r(make_url => 1);
like($t->mech->uri, qr#/test/swit/r#);
like($t->mech->content, qr/hello world/);

$t->redirect_r(make_url => 1, param => { internal => 1 });
like($t->mech->uri, qr#/test/redirect/r#);
like($t->mech->content, qr/hello world/);
