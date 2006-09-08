use strict;
use warnings FATAL => 'all';

use Test::More tests => 26;
use File::Slurp;

BEGIN { use_ok('Apache::SWIT::Maker');
	use_ok('Apache::SWIT::Test::ModuleTester');
}

use Carp;
BEGIN { $SIG{__DIE__} = sub { diag(Carp::longmess); } };


my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;

`modulemaker -I -n TTT`;
ok(-f './TTT/LICENSE');
chdir 'TTT';

Apache::SWIT::Maker->new->write_initial_files();
ok(-f "conf/startup.pl");
is(Apache::SWIT::Maker::Config->instance->app_name, 'ttt');

`./scripts/swit_app.pl add_class TTT::SomeClass`;
ok(-f 'lib/TTT/SomeClass.pm');

`./scripts/swit_app.pl add_class AnotherClass`;
ok(-f 'lib/TTT/AnotherClass.pm');

my $res = `./scripts/swit_app.pl add_class AnotherClass 2>&1`;
isnt($?, 0);
like($res, qr/refusing/);

`./scripts/swit_app.pl add_ht_page TTT::SomePage`;
ok(-f 'lib/TTT/SomePage.pm');
my @recs = `grep SomePage MANIFEST`;
is(scalar(@recs), 1);

undef $Apache::SWIT::Maker::Config::_instance;
my $e = Apache::SWIT::Maker::Config->instance->pages->{somepage};
ok($e);
$e->{ddd} = 1;
Apache::SWIT::Maker::Config->instance->save;
like(read_file('conf/swit.yaml'), qr/ddd/);

ok(-f 'templates/somepage.tt');
append_file('templates/somepage.tt', "bobo");
$res = `./scripts/swit_app.pl add_ht_page TTT::SomePage 2>&1`;
isnt($?, 0);
like(read_file('templates/somepage.tt'), qr/bobo/);
like(read_file('conf/swit.yaml'), qr/ddd/);

unlike(`diff -u Makefile.PL MANIFEST`, qr/newline/);

`./scripts/swit_app.pl add_ht_page AnotherPage`;
ok(-f 'lib/TTT/UI/AnotherPage.pm');

my $lines = `perl Makefile.PL && make install SITEPREFIX=$td/inst 2>&1`;
is($?, 0) or do {
	diag($lines);
#	diag("$td");
#	readline(\*STDIN);
};
isnt(-d "$td/inst/share/ttt", undef);
is(-d "$td/inst/share/perl", undef);

like(read_file("$td/inst/share/ttt/conf/httpd.conf"), 
		qr#TTT_ROOT $td/inst/share/ttt\n#) or diag($lines);
ok(-f "public_html/main.css");
ok(-f "blib/public_html/main.css");
ok(-f "$td/inst/share/ttt/public_html/main.css");

chdir '/';
