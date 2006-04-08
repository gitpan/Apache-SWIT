use strict;
use warnings FATAL => 'all';

use Test::More tests => 15;
use Test::TempDatabase;
use File::Slurp;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');
ok(-f 'lib/TTT/DB/Schema.pm');

$mt->insert_into_schema_pm('\$dbh->do("create table the_table ('
	. 'id serial primary key, col1 text, col2 integer)")');

my @res = `./scripts/swit_app.pl scaffold the_table 2>&1`;
is(@res, 0) or diag(join('', @res));
ok(-f 'lib/TTT/DB/TheTable.pm');
ok(-f 'lib/TTT/UI/TheTable/List.pm');
ok(-f 'lib/TTT/UI/TheTable/Form.pm');
ok(-f 't/dual/011_the_table.t');

my $tstr = read_file('t/dual/011_the_table.t');
unlike($tstr, qr/first/);
unlike($tstr, qr/\bid/);
like($tstr, qr/col1/);

my $make = "perl Makefile.PL && make";
my $res = `$make test_direct APACHE_TEST_FILES=t/dual/011_the_table.t 2>&1`;
unlike($res, qr/Failed/);
like($res, qr/success/);

$res = `make test_apache APACHE_TEST_FILES=t/dual/011_the_table.t 2>&1`;
unlike($res, qr/Failed/);
like($res, qr/success/);

chdir '/';
