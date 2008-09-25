use strict;
use warnings FATAL => 'all';

use Test::More tests => 17;
use Apache::SWIT::Session;
use Apache::SWIT::Test::Utils;

BEGIN { use_ok('T::Test');
	use_ok('T::Safe');
};

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;

T::Test->root_location('/test');
T::Test->make_aliases(safe => 'T::Safe');
my $t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
$t->ok_ht_safe_r(make_url => 1, ht => { name => '', email => '' });
$t->ht_safe_u(ht => { name => 'foo', email => 'boo' });
$t->ok_ht_safe_r(ht => { name => '', email => '' });
unlike($t->mech->content, qr/Name cannot be empty/);
is_deeply($dbh->selectcol_arrayref("select count(*) from safet"), [ 1 ]);

$t->ht_safe_u(ht => { name => '', email => 'fooo' });
$t->ok_ht_safe_r(ht => { name => '', email => 'fooo' });
like($t->mech->content, qr/Name cannot be empty/);
unlike($t->mech->content, qr/Email cannot be empty/);

$t->ht_safe_u(ht => { name => '', email => '' });
$t->ok_ht_safe_r(ht => { name => '', email => '' });
like($t->mech->content, qr/Name cannot be empty/);
like($t->mech->content, qr/Email cannot be empty/);

$t->ht_safe_u(ht => { name => 'foo', email => 'ema' });
$t->ok_ht_safe_r(ht => { name => 'foo', email => 'ema' });
like($t->mech->content, qr/This name exists already/) or ASTU_Wait;

$t->ht_safe_u(ht => { name => 'fooa', email => 'ema b' });
$t->ok_ht_safe_r(ht => { name => 'fooa', email => 'ema b' });
is_deeply($dbh->selectcol_arrayref("select count(*) from safet"), [ 1 ]);
like($t->mech->content, qr/Email is invalid/) or ASTU_Wait;
