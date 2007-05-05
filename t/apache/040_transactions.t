use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::TransFailure');
};

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
ok($dbh->do("create table trans (a smallint not null check (a > 10))"));

$ENV{SWIT_HAS_APACHE} = 0;
Apache::SWIT::Test->make_aliases(trans_fail => 'T::TransFailure');

my $t = Apache::SWIT::Test->new;
eval { $t->ht_trans_fail_u(ht => {}); };
like($@, qr/check constraint/); 
like($@, qr/fail\/u/); 
is_deeply($dbh->selectall_arrayref("select * from trans"), []);
