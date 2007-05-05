use strict;
use warnings FATAL => 'all';

use Test::More tests => 18;
use YAML;
use Data::Dumper;
use File::Slurp;

BEGIN { use_ok('Apache::SWIT::Subsystem::Maker');
	use_ok('Apache::SWIT::Test::ModuleTester');
}

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;
$mt->run_modulemaker_and_chdir;
ok(-f 'LICENSE');

Apache::SWIT::Subsystem::Maker->new->write_initial_files();
is(-f './t/001_load.t', undef);
isnt(-f './conf/startup.pl', undef);

my $res = `scripts/swit_app.pl add_ht_page BB`;
is($?, 0);
ok(-f 'lib/TTT/UI/BB.pm');

undef $Apache::SWIT::Maker::Config::_instance;
my $tree = Apache::SWIT::Maker::Config->instance;
$tree->{pages}->{"index"}->{entry_points}->{r}->{foo} = 'boo';
isnt(delete $tree->{pages}->{bb}->{entry_points}, undef);
$tree->{pages}->{bb}->{handler} = 'some_handler';
$tree->save;

undef $Apache::SWIT::Maker::Config::_instance;
$tree = Apache::SWIT::Maker::Config->instance;
my $ind = $tree->{pages}->{"index"};
is($ind->{entry_points}->{r}->{foo}, 'boo');

$res = join('', `perl Makefile.PL && make 2>&1`);
is($?, 0) or diag($res);
unlike($res, qr/950/);

my $hc = read_file('blib/conf/httpd.conf');
like($hc, qr#Location /ttt/bb#);
like($hc, qr#BB->some_handler#);

$res = $mt->run_make_install;
my $inst_path = $mt->install_dir . "/TTT";
ok(-f "$inst_path/Maker.pm");

chdir $td;
$mt->make_swit_project(root_class => 'MU');
$mt->install_subsystem('TheSub');

undef $Apache::SWIT::Maker::Config::_instance;
$tree = Apache::SWIT::Maker::Config->instance;
$ind = $tree->{pages}->{"thesub/index"};
isnt($ind, undef) or diag(Dumper($tree));
is($ind->{entry_points}->{r}->{template}, 'templates/thesub/index.tt');
unlike(Dumper($ind), qr/html/);
is($ind->{entry_points}->{r}->{foo}, 'boo')
	 or diag(Dumper($tree));

chdir '/';
