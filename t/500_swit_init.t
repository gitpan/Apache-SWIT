use strict;
use warnings FATAL => 'all';

use Test::More tests => 59;
use File::Temp qw(tempdir);
use Data::Dumper;
use File::Path qw(rmtree);
use Test::TempDatabase;
use Apache::SWIT::Test::ModuleTester;
use File::Slurp;

BEGIN { use_ok('Apache::SWIT::Maker'); }

delete $ENV{TEST_FILES};
delete $ENV{MAKEFLAGS};
delete $ENV{MAKEOVERRIDES};

Test::TempDatabase->become_postgres_user;
my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');

my $swit_str = read_file('conf/swit.yaml');
like($swit_str, qr/TTT/);
like($swit_str, qr/\/ttt/);
like($swit_str, qr/TTT::Session/);
ok(-f "conf/httpd.conf.in");
ok(-f "lib/TTT/Session.pm");

`./scripts/swit_app.pl add_test t/dual/newdir/987_test.t`;
ok(-f 't/dual/newdir/987_test.t');

$mt->replace_in_file('t/apache_test_run.pl', '\);', ', "gogog");');
$mt->replace_in_file('t/dual/001_load.t', '=> 6', '=> 8');
append_file('t/dual/001_load.t', <<'ENDM');
if ($t->mech) {
	ok(-d $ENV{SWIT_TEST_DIR});
	ok(-d $ENV{SWIT_TEST_DIR} . "/gogog");
} else {
	ok(1);
	ok(1);
}
ENDM

my @tmp_contents = glob('/tmp/*');
`perl Makefile.PL`;
my $tres = join('', `make test 2>&1`);
like($tres, qr/All tests successful/);
like($tres, qr/t\/dual\/001_load/);
like($tres, qr/started\n.*dual/);
like($tres, qr/Files=2/);
unlike($tres, qr/Error/);
like($tres, qr/987_test/);
ok(-d 't/logs');
ok(-f 'blib/conf/httpd.conf');
is_deeply([ glob("/tmp/*") ], \@tmp_contents);

is_deeply([ `psql -l | grep ttt_test_db` ], []) or diag($tres);

#diag($td);
#readline(\*STDIN);
like(read_file('t/logs/access_log'), qr/ttt\/index.*200/);

# Check that we run configuration only once
$tres = join('', `make 2>&1`);
unlike($tres, qr/configuration/);

# But now config should be regenerated
`touch t/conf/extra.conf.in`;
$tres = join('', `make 2>&1`);
like($tres, qr/configuration/);

# make test_ doesn't run apache
$tres = join('', `make test_ 2>&1`);
unlike($tres, qr/started/);

# make test_direct doesn't run neither apache nor other tests
$tres = join('', `make test_direct 2>&1`);
unlike($tres, qr/started/);
unlike($tres, qr/t\/001_load/);
like($tres, qr/dual/);

`./scripts/swit_app.pl add_page First::Page`;
like(read_file('conf/swit.yaml'), qr/TTT::UI::First::Page/);

ok(-f "templates/first/page.tt");
ok(-f "lib/TTT/UI/First/Page.pm");

open(my $fh, ">>conf/httpd.conf.in");
print $fh "# Custom\n";
close $fh;

my $ht_conf = read_file('conf/httpd.conf.in');
unlike($ht_conf, qr/TTT::Session/);
like($ht_conf, qr/SessionClass/);

`make 2>&1`;
$ht_conf = read_file('blib/conf/httpd.conf');
like($ht_conf, qr/Location \/ttt\/first\/page/);
like($ht_conf, qr/Custom/);
like($ht_conf, qr/TTT::Session/);

my $mani = read_file('MANIFEST');
like($mani, qr/TTT\/UI\/First\/Page\.pm/);
like($mani, qr/templates\/first\/page\.tt/);
like($mani, qr/conf\/httpd\.conf\.in/);
like($mani, qr/direct_test/);

$tres = join('', `make dist 2>&1`);
like($tres, qr/apache_test/);
like($tres, qr/dual/);
like($tres, qr/extra/);

`make realclean`;
ok(! -f 't/T/Test.pm');
ok(! -d 't/htdocs');
ok(! -d 't/logs');
ok(! -f 'blib/conf/httpd.conf');
is_deeply([ glob('t/conf/*') ], [ 't/conf/extra.conf.in' ]);

undef $Apache::SWIT::Maker::Config::_instance;
Apache::SWIT::Maker->remove_page('First::Page');
unlike(read_file('conf/swit.yaml'), qr/TTT::UI::First::Page/);
$mani = read_file('MANIFEST');
unlike($mani, qr/TTT\/UI\/First\/Page\.pm/);
unlike($mani, qr/templates\/first\/page\.tt/);
ok(! -f "templates/first/page.tt");
ok(! -f "lib/TTT/UI/First/Page.pm");

Apache::SWIT::Maker->new->add_ht_page('First::Page');
like(read_file('conf/swit.yaml'), qr/TTT::UI::First::Page/);
like(read_file('lib/TTT/UI/First/Page.pm'), qr/ht_root_class/);
ok(require("lib/TTT/UI/First/Page.pm"));

my $at = read_file('t/apache_test.pl');
open($fh, ">t/apache_test.pl");
print $fh "use TTT::UI::First::Page;\n$at";
close $fh;

is_deeply([ `psql -l | grep ttt_test_db` ], []);
`perl Makefile.PL`;
$tres = join('', `make test_apache 2>&1`);
like($tres, qr/All tests successful/);
unlike($tres, qr/Fail/);
is_deeply([ `psql -l | grep ttt_test_db` ], []);

$tres = join('', `make disttest 2>&1`);
unlike($tres, qr/Fail/);
is_deeply([ `psql -l | grep ttt_test_db` ], []);

chdir '/';
rmtree('/tmp/ttt_sessions');
