use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;
use Apache::SWIT::Session;

BEGIN { use_ok('T::Test');
	use_ok('T::TransFailure');
};

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
ok($dbh->do(<<ENDS));
set client_min_messages to error;
create table trans (a smallint not null check (a > 10) primary key);
create table t2 (b smallint primary key references trans(a)
		initially deferred);
ENDS

$ENV{SWIT_HAS_APACHE} = 0;
T::Test->make_aliases(trans_fail => 'T::TransFailure');

my $t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
eval { $t->ht_trans_fail_u(ht => {}); };
like($@, qr/check constraint/); 
like($@, qr/fail\/u/); 
is_deeply($dbh->selectall_arrayref("select * from trans"), []);

# check that swit_die works on commit
eval { $t->ht_trans_fail_u(ht => { fail_on_commit => 1 }); };
like($@, qr/fail_on_commit/); 

ok($t->ht_trans_fail_u(ht => { rollback => 1 }));
