use strict;
use warnings FATAL => 'all';

use Test::More tests => 11;
use YAML;
use Data::Dumper;

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

my $tree = YAML::LoadFile('conf/swit.yaml');
$tree->{pages}->{"index"}->{entry_points}->{r}->{foo} = 'boo';
YAML::DumpFile('conf/swit.yaml', $tree);

$tree = Apache::SWIT::Maker->load_yaml_conf;
my $ind = $tree->{pages}->{"index"};
is($ind->{entry_points}->{r}->{foo}, 'boo');

my $res = join('', `perl Makefile.PL && make 2>&1`);
unlike($res, qr/950/);

$res = $mt->run_make_install;
my $inst_path = $mt->install_dir . "/TTT";
ok(-f "$inst_path/Maker.pm");

chdir $td;
$mt->make_swit_project(root_class => 'MU');
$mt->install_subsystem('TheSub');

$tree = Apache::SWIT::Maker->load_yaml_conf;
$ind = $tree->{pages}->{"thesub/index"};
isnt($ind, undef) or diag(Dumper($tree));
is($ind->{entry_points}->{r}->{template}, 'templates/thesub/index.tt');
unlike(Dumper($ind), qr/html/);
is($ind->{entry_points}->{r}->{foo}, 'boo')
	 or diag(Dumper($tree));

chdir '/';
