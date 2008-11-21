use strict;
use warnings FATAL => 'all';

use Test::More tests => 26;
use Apache::SWIT::Session;
use Apache::SWIT::Test::Utils;

BEGIN { use_ok('T::Test');
	use_ok('T::Safe');
};

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;

T::Test->root_location('/test');
T::Test->make_aliases(safe => 'T::Safe');
my $t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
$t->ok_ht_safe_r(make_url => 1, ht => { name => '', email => ''
	, sl => [ { o => '1' }, { o => '2' } ] });
like($t->mech->content, qr/html>\n$/) or exit 1;

$t->ht_safe_u(ht => { name => 'foo', email => 'boo' });
$t->ok_ht_safe_r(ht => { name => '', email => '' });
unlike($t->mech->content, qr/Name cannot be empty/);
is_deeply($dbh->selectcol_arrayref("select count(*) from safet"), [ 1 ]);

$t->ht_safe_u(ht => { name => '', email => 'fooo' });
$t->ok_ht_safe_r(ht => { name => '', email => 'fooo' });
like($t->mech->content, qr/Name cannot be empty/);
unlike($t->mech->content, qr/Email cannot be empty/);

# if we get different ending from the above it means our headers are screwed.
# We had these problems when using subrequests instead of internal redirects.
like($t->mech->content, qr/html>\n$/) or exit 1;

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

$t->ht_safe_u(ht => { name => 'hee', email => 'e@example.com', sl => [ {
	o => 10 }, { o => 'a' } ] });
$t->ok_ht_safe_r(ht => { name => 'hee', email => 'e@example.com', sl => [ {
	o => 10 }, { o => 'a' } ] });
like($t->mech->content, qr/o integer/);

$ENV{SWIT_HAS_APACHE} = 0;
$t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
is($t->mech, undef);

# check that we die on validation error
eval { $t->ht_safe_u(ht => { name => 'die' }); };
like($@, qr/Found errors/);

my @res = $t->ht_safe_u(ht => { name => 'die' }, error_ok => 1);
like($res[0]->[1], qr/swit_errors.*email/);

my $a = 'abc';
$a =~ /a(.)c/;
ok($1); # to catch die exception we need to have $1 defined

# check that we still die when exception is unknown
eval { $t->ht_safe_u(ht => { name => 'die', email => 'foo' }); };
like($@, qr/BUGBUGBUG/);
