use strict;
use warnings FATAL => 'all';

use Test::More tests => 12;
use Data::Dumper;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::Session');
	use_ok('T::SessPage');
}

$ENV{SWIT_HAS_APACHE} = 0;

Apache::SWIT::Test->make_aliases(sess_page => 'T::SessPage');

my $t = Apache::SWIT::Test->new({ session_class => 'T::Session' });
$t->ok_ht_sess_page_r(ht => { persbox => '' });
my @x = $t->ht_sess_page_u(ht => { persbox => "hello" });
is_deeply(\@x, [ '/test/sess_page/r' ]);
$t->ok_ht_sess_page_r(ht => { persbox => 'hello' });

$ENV{SWIT_HAS_APACHE} = 1;
$t = Apache::SWIT::Test->new;
$t->ok_ht_sess_page_r(base_url => '/test/sess_page/r', ht => { persbox => '' });
$t->ok_get('/test/www/hello.html');
$t->ok_ht_sess_page_r(base_url => '/test/sess_page/r', ht => { persbox => '' });
like($t->mech->cookie_jar->as_string, qr/foo/);

$t->ht_sess_page_u(ht => { persbox => 'life' });
$t->ok_ht_sess_page_r(ht => { persbox => 'life' });

# and now it is going to be denied by Session
$t->ok_get('/test/www/hello.html', 403);


