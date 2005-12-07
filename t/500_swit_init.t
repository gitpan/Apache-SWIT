use strict;
use warnings FATAL => 'all';

use Test::More tests => 53;
use File::Temp qw(tempdir);
use Data::Dumper;
use File::Path qw(rmtree);
use Test::TempDatabase;

BEGIN { use_ok('Apache::SWIT::Maker'); }

sub read_file {
	my $f = shift;
	open(my $fh, $f) or die "Unable to open $f\n";
	my $res = join('', <$fh>);
	close $fh;
	return $res;
}

delete $ENV{TEST_FILES};
delete $ENV{MAKEFLAGS};
delete $ENV{MAKEOVERRIDES};

Test::TempDatabase->become_postgres_user;
my $td = tempdir('/tmp/swit_init_XXXXXX', CLEANUP => 1);
chdir $td;
`modulemaker -I -n TTT`;
ok(-f './TTT/LICENSE');
chdir 'TTT';

Apache::SWIT::Maker->new->write_initial_files();
my $swit_str = read_file('conf/swit.yaml');
like($swit_str, qr/TTT/);
like($swit_str, qr/\/ttt/);
like($swit_str, qr/TTT::Session/);
ok(-f "conf/httpd.conf.in");
ok(-f "lib/TTT/Session.pm");

`perl Makefile.PL`;
my $tres = join('', `make test 2>&1`);
like($tres, qr/All tests successful/);
like($tres, qr/t\/dual\/001_load/);
like($tres, qr/started\n.*dual/);
like($tres, qr/Files=1/);
ok(-d 't/logs');
ok(-f 'conf/httpd.conf');
ok(-d '/tmp/ttt_sessions');

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

Apache::SWIT::Maker->new->add_page('First::Page');
like(read_file('conf/swit.yaml'), qr/TTT::First::Page/);

ok(-f "templates/first/page.tt");
ok(-f "lib/TTT/First/Page.pm");
ok(-f "conf/startup.pl");

open(my $fh, ">>conf/httpd.conf.in");
print $fh "# Custom\n";
close $fh;

`make 2>&1`;
my $ht_conf = read_file('conf/httpd.conf');
like($ht_conf, qr/Location \/ttt\/first\/page/);
like($ht_conf, qr/Custom/);
like($ht_conf, qr/TTT::Session/);

my $mani = read_file('MANIFEST');
like($mani, qr/TTT\/First\/Page\.pm/);
like($mani, qr/templates\/first\/page\.tt/);
like($mani, qr/conf\/httpd\.conf\.in/);
like($mani, qr/conf\/startup\.pl/);
like($mani, qr/direct_test/);

$tres = join('', `make dist 2>&1`);
like($tres, qr/apache_test/);
like($tres, qr/dual/);
like($tres, qr/extra/);

`make realclean`;
ok(! -f 't/T/Test.pm');
ok(! -d 't/htdocs');
ok(! -d 't/logs');
ok(! -f 'conf/httpd.conf');
is_deeply([ glob('t/conf/*') ], [ 't/conf/extra.conf.in' ]);

Apache::SWIT::Maker->remove_page('First::Page');
unlike(read_file('conf/swit.yaml'), qr/TTT::First::Page/);
$mani = read_file('MANIFEST');
unlike($mani, qr/TTT\/First\/Page\.pm/);
unlike($mani, qr/templates\/first\/page\.tt/);
ok(! -f "templates/first/page.tt");
ok(! -f "lib/TTT/First/Page.pm");

Apache::SWIT::Maker->new->add_ht_page('First::Page');
like(read_file('conf/swit.yaml'), qr/TTT::First::Page/);
like(read_file('lib/TTT/First/Page.pm'), qr/ht_root_class/);
ok(require("lib/TTT/First/Page.pm"));

my $at = read_file('t/apache_test.pl');
open($fh, ">t/apache_test.pl");
print $fh "use TTT::First::Page;\n$at";
close $fh;

`perl Makefile.PL`;
$tres = join('', `make test_apache 2>&1`);
like($tres, qr/All tests successful/);

$tres = join('', `make disttest 2>&1`);
unlike($tres, qr/Fail/);
is_deeply([ `psql -l | grep ttt_test_db` ], []);

chdir '/';
rmtree('/tmp/ttt_sessions');
