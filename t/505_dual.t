use strict;
use warnings FATAL => 'all';

use Test::More tests => 18;
use File::Slurp;
use Test::TempDatabase;
use Cwd;
use YAML;
use Apache::SWIT::Test::Utils;

Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $cwd = getcwd;

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;
$mt->run_modulemaker_and_chdir;

is(system("$cwd/scripts/swit_init"), 0);
isnt(-f "conf/swit.yaml", undef);
unlike(read_file("lib/TTT/UI/Index.pm"), qr/sub ht_root_class/);

`./scripts/swit_app.pl add_page Red`;
is($?, 0);
$mt->replace_in_file("lib/TTT/UI/Red.pm", "swit_render {", <<ENDS);
swit_render {
	return [ INTERNAL => "../index/r" ];
ENDS

write_file('t/dual/030_load.t', <<'ENDS');
use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;
use File::Slurp;

BEGIN { use_ok('T::Test'); };

my $t = T::Test->new;
$t->with_or_without_mech_do(1, sub { ok 1; write_file("A", ""); },
		1, sub { ok 1; write_file("D", ""); });
$t->ok_ht_index_r(make_url => 1, ht => { first => '' });
$t->content_like(qr/hrum/);
$t->red_r(make_url => 1);
$t->content_like(qr/hrum/);
$t->with_or_without_mech_do(1, sub {
	like($t->mech->uri, qr#red/r#);
});
$t->aga_html_r(make_url => 1);
$t->content_like(qr/hrum/);
ENDS

like(read_file("lib/TTT/UI/Index.pm"), qr/sub swit_startup/);
$mt->replace_in_file("lib/TTT/UI/Index.pm", 'sub swit_startup {', <<ENDS);
use File::Slurp;
sub swit_startup {
	append_file("$td/swit_startup_test", sprintf("\%d \%s \%s\n"
			, \$\$, \$0, (caller)[1]));
ENDS
append_file('templates/index.tt', '[% INCLUDE templates/inc.tt %]');
write_file('templates/inc.tt', "hrum\nhrum\n");
append_file('MANIFEST', "\ntemplates/inc.tt\n");

my $res = `./scripts/swit_app.pl add_class SC`;
is($?, 0);
$mt->replace_in_file("lib/TTT/SC.pm", "1;", <<ENDS);
use File::Slurp;
sub swit_startup {
	append_file("$td/startup_classes_test", \$_[0]);
}
1;
ENDS

my $tree = YAML::LoadFile('conf/swit.yaml');
isnt($tree, undef);
$tree->{startup_classes} = [ 'TTT::SC' ];

$tree->{pages}->{"aga.html"} = { class => 'TTT::UI::Red'
			, handler => 'swit_render_handler' };
YAML::DumpFile('conf/swit.yaml', $tree);

$res = `perl Makefile.PL && make test_dual 2>&1`;
like($res, qr/030_load/);
like($res, qr/success/) or ASTU_Wait();
unlike($res, qr/Fail/) or ASTU_Wait;
unlike($res, qr/010_db/);
isnt(-f "A", undef) or diag($res);
isnt(-f "D", undef);

my $sws = read_file("$td/swit_startup_test");
like($sws, qr/do_swit_startups\.pl/);
unlike($sws, qr/httpd\.conf/);

my $sct = read_file("$td/startup_classes_test");
like($sws, qr/do_swit_startups\.pl/);
unlike($sws, qr/httpd\.conf/);

chdir '/';
