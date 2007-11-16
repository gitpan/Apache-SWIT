use strict;
use warnings FATAL => 'all';

use Test::More tests => 15;
use Test::TempDatabase;
use File::Slurp;
use Apache::SWIT::Test::Utils;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');

$mt->insert_into_schema_pm(<<'ENDM');
$dbh->do("create table the_table (id serial primary key, col1 text)");
ENDM

my $lstr = read_file('t/dual/001_load.t');
append_file('t/dual/001_load.t', <<'ENDM');
my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
$dbh->do("insert into the_table (col1) values ('aaa')");
`pg_dump $ENV{APACHE_SWIT_DB_NAME} > pgd.sql`;
ENDM

my $res = `perl Makefile.PL && make test_direct 2>&1`;
is($?, 0) or ASTU_Wait($res);
like(read_file('pgd.sql'), qr/aaa/);
write_file('t/dual/001_load.t', $lstr);

append_file('lib/TTT/DB/Schema.pm', <<'ENDM');
__PACKAGE__->add_version(sub {
	my $dbh = shift;
$dbh->do("alter table the_table add column col2 text;
		update the_table set col2 = 'bbb';");
});
ENDM

$res = `./scripts/swit_app.pl scaffold the_table 2>&1`;
is($?, 0) or ASTU_Wait($res);

$res = `perl Makefile.PL && make test_direct 2>&1`;
is($?, 0) or ASTU_Wait($res);

$res = `./scripts/swit_app.pl add_migration mig pgd.sql 2>&1`;
is($?, 0) or ASTU_Wait($res);
is($res, '');
ok(-f 't/mig/db.sql');
like(read_file('MANIFEST'), qr#t/mig/db.sql#);

write_file('t/mig/111_m.t', <<'ENDM');
use strict;
use warnings FATAL => 'all';

use Test::More tests => 5;
BEGIN { use_ok('T::Test'); }

my $arr = Apache::SWIT::DB::Connection->instance->db_handle
		->selectcol_arrayref("select col1 from the_table");
is(scalar(@$arr), 1);

my $t = T::Test->new;
$t->ok_ht_thetable_list_r(make_url => 1, ht => {});
like($t->mech->content, qr/aaa/);
like($t->mech->content, qr/bbb/);
ENDM

$res = `make test_mig 2>&1`;
is($?, 0) or ASTU_Wait($res);
like($res, qr/start: ok/);
like($res, qr/111_m/);

$res = `make test 2>&1`;
is($?, 0) or ASTU_Wait($res);
like($res, qr/111_m/);
