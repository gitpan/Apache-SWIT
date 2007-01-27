use strict;
use warnings FATAL => 'all';

use Test::More tests => 26;
use Test::TempDatabase;
use File::Slurp;
use Apache::SWIT::Test::Utils;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester');
	use_ok('Apache::SWIT::Subsystem::Maker');
};

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;
$mt->run_modulemaker_and_chdir;
ok(-f 'LICENSE');

Apache::SWIT::Subsystem::Maker->new->write_initial_files();
is(-f './lib/TTT/DB/Connection.pm', undef);
is(-f './t/T/TTT/DB/Connection.pm', undef);

$mt->insert_into_schema_pm('$dbh->do("create table the_table (
	id serial primary key, col1 text, col2 integer)");
$dbh->do("create table one_col_table (id serial primary key, ocol text)");
');

my $res = `./scripts/swit_app.pl add_db_class one_col_table`;
is($?, 0) or diag($res);
ok(-f 'lib/TTT/DB/OneColTable.pm');
like(read_file('lib/TTT/DB/OneColTable.pm'), qr/on_inheritance_end/);
like(read_file('conf/swit.yaml'), qr/OneColTable/);

write_file('t/234_one_col.t', <<'ENDT');
use strict;
use warnings FATAL => 'all';
use Test::More tests => 3;
use T::TempDB;
BEGIN { use_ok('T::TTT'); }

my $t = T::TTT->db_onecoltable_class->create({ ocol => 'AAA' });
is($t->id, 1);
is_deeply([ T::TTT->db_onecoltable_class->retrieve_all ], [ $t ]);
ENDT

$res = `perl Makefile.PL && make 2>&1`;
is($?, 0) or diag($res);
like(read_file('blib/lib/TTT/PageClasses.pm'), qr/OneColTable/);

$res = `make test_ TEST_FILES=t/234_one_col.t 2>&1`;
is($?, 0) or diag($res);

$res = `./scripts/swit_app.pl scaffold the_table 2>&1`;
is($?, 0) or do {
	diag($res);
	diag($td);
#	readline(\*STDIN);
};

$res = `make realclean && perl Makefile.PL && make 2>&1`;
is($?, 0) or diag($res);

$res = read_file('blib/lib/TTT/PageClasses.pm');
like($res, qr/Form/);
like($res, qr/List/);
like($res, qr/Info/);
unlike(read_file('t/dual/011_the_table.t'), qr/Form/);

$res = `make test_direct APACHE_TEST_FILES=t/dual/011_the_table.t 2>&1`;
is($?, 0);
unlike($res, qr/Failed/) or ASTU_Wait($td);
like($res, qr/success/);
unlike($res, qr/make_tested/);
unlike($res, qr/Please use/);

$res = `make test_apache APACHE_TEST_FILES=t/dual/011_the_table.t 2>&1`;
is($?, 0);
unlike($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/success/);

chdir '/';
