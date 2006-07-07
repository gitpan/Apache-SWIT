use strict;
use warnings FATAL => 'all';

use Test::More tests => 22;
use Test::TempDatabase;
use File::Slurp;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');
ok(-f 'lib/TTT/DB/Schema.pm');

$mt->insert_into_schema_pm('$dbh->do("create table the_table (
	id serial primary key, col1 text, col2 integer)");
$dbh->do("create table one_col_table (id serial primary key, ocol text)");
');

my @res = `./scripts/swit_app.pl scaffold the_table 2>&1`;
is(@res, 0) or diag(join('', @res));
ok(-f 'lib/TTT/DB/TheTable.pm');
ok(-f 'lib/TTT/UI/TheTable/List.pm');
ok(-f 'lib/TTT/UI/TheTable/Form.pm');
ok(-f 'lib/TTT/UI/TheTable/Info.pm');
ok(-f 't/dual/011_the_table.t');

my $tstr = read_file('t/dual/011_the_table.t');
unlike($tstr, qr/first/);
unlike($tstr, qr/\bid/);
like($tstr, qr/col1/);

my $make = "perl Makefile.PL && make";
my $res = `$make test_direct APACHE_TEST_FILES=t/dual/011_the_table.t 2>&1`;
unlike($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/success/);

$res = `make test_apache APACHE_TEST_FILES=t/dual/011_the_table.t 2>&1`;
unlike($res, qr/Failed/);
like($res, qr/success/);

# HTML::Form input readonly warning on hidden
unlike($res, qr/readonly/);

@res = `./scripts/swit_app.pl scaffold one_col_table 2>&1`;
is(@res, 0) or diag(join('', @res));
ok(-f 'lib/TTT/DB/OneColTable.pm');
ok(-f 't/dual/021_one_col_table.t');

$res = `$make test_direct APACHE_TEST_FILES=t/dual/021_one_col_table.t 2>&1`;
unlike($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/success/);

chdir '/';
