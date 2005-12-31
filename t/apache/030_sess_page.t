use strict;
use warnings FATAL => 'all';

use Test::More tests => 9;
use Data::Dumper;
use Carp;

BEGIN { use_ok('T::Session');
	use_ok('T::SessPage');
	use_ok('Apache::SWIT::Test');
	$SIG{__DIE__} = sub { print STDERR "# " . Carp::longmess(@_); };
}

Apache::SWIT::Test->make_aliases(sess_page => 'T::SessPage');

my $t = Apache::SWIT::Test->new({ session_class => 'T::Session' });
$t->ok_ht_sess_page_r(ht => { persbox => '' });
my @x = $t->ht_sess_page_u(ht => { persbox => "hello" });
is_deeply(\@x, [ '/test/sess_page/r' ]);
$t->ok_ht_sess_page_r(ht => { persbox => 'hello' });

$ENV{SWIT_HAS_APACHE} = 1;
$t = Apache::SWIT::Test->new;
$t->ok_ht_sess_page_r(base_url => '/test/sess_page/r', ht => { persbox => '' });
like($t->mech->cookie_jar->as_string, qr/foo/);

$t->ht_sess_page_u(ht => { persbox => 'life' });
$t->ok_ht_sess_page_r(ht => { persbox => 'life' });


