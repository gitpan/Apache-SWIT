use strict;
use warnings FATAL => 'all';

use Test::More tests => 47;
use File::Temp qw(tempdir);
use Data::Dumper;
use Test::TempDatabase;
use YAML;
use File::Slurp;
Test::TempDatabase->become_postgres_user;
use Apache::SWIT::Test::Utils;

BEGIN { use_ok('Apache::SWIT::Subsystem::Maker');
	use_ok('Apache::SWIT::Test::ModuleTester');
	use_ok('Apache::SWIT::Test::Apache');
}

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;
$mt->run_modulemaker_and_chdir;
ok(-f 'LICENSE');

Apache::SWIT::Subsystem::Maker->new->write_initial_files();
is(-f './lib/TTT/DB/Connection.pm', undef);
is(-f './t/T/TTT/DB/Connection.pm', undef);
is(-f './t/001_load.t', undef);
is(-f 'lib/TTT/DB/Base.pm', undef);
like(read_file('Makefile.PL'),
	       	qr/Apache::SWIT::Subsystem::Makefile/);

Apache::SWIT::Subsystem::Maker->new->write_pm_file('TTT::DB::Random', <<ENDF);
sub number { return 494; }
ENDF

$mt->replace_in_file('lib/TTT.pm', '__PACKAGE__'
		, '__PACKAGE__, "DB::Random"');
$mt->replace_in_file('lib/' . $mt->module_dir . "/Session.pm", '1', <<ENDM);
sub on_inheritance_end {
	my \$class = shift;
	\$class->add_var('username');

	my \$n = lc(\$class->main_subsystem_class);
	\$n =~ s/::/_/g;
	\$class->add_var(\$n);
	\$class->add_class_dbi_var('pseudo', 
			\$class->main_subsystem_class->ui_index_class);
}

1;
ENDM

write_file("t/555_test.t", <<'ENDT');
use Test::More tests => 8;
BEGIN { use_ok('T::TTT'); }
is(T::TTT::DB::Random->number, 494);
is(T::TTT->db_random_class, 'T::TTT::DB::Random');
is(T::TTT::DB::Random->main_subsystem_class, 'T::TTT');
is(T::TTT::UI::Index->main_subsystem_class, 'T::TTT');
is(T::TTT->templates_dir, 'templates/');
is(T::TTT::Session->cookie_name, 'ttt');
can_ok(T::TTT::Session, 'get_t_ttt');
ENDT

my $tree = Apache::SWIT::Maker::Config->instance;
$tree->{pages}->{"index"}->{entry_points}->{r}->{foo} = 'boo';
$tree->save;

undef $Apache::SWIT::Maker::Config::_instance;
$tree = Apache::SWIT::Maker::Config->instance;
my $ind = $tree->{pages}->{"index"};
is($ind->{entry_points}->{r}->{foo}, 'boo');

my $res = join('', `perl Makefile.PL && make 2>&1`);
is($?, 0) or diag($res);

my $ht_conf = read_file('blib/conf/httpd.conf');
like($ht_conf, qr/T::TTT::UI::Index/);
like($ht_conf, qr/T::TTT::Session/);

my $ind_str = read_file('lib/TTT/UI/Index.pm');
unlike($ind_str, qr/\.tt/);
like($ind_str, qr/ht_root.+Root/);

my $m_str = read_file('MANIFEST');
unlike($m_str, qr/Test\.pm/);
unlike($m_str, qr/PageClasses\.pm/);

$res = join('', `make test 2>&1`);
unlike($res, qr/Error/) or do {
	diag("$td");
#	readline(\*STDIN);
};
like($res, qr/success/);
like($res, qr/localhost/);
like($res, qr/950_install/);

append_file('conf/startup.pl', '`touch $ENV{TTT_ROOT}/touched`; 1;');
$res = join('', `make test_apache 2>&1`);
like($res, qr/success/); # or readline(\*STDIN);

like(read_file('blib/conf/startup.pl'), qr/touch/);
ok(-f 'blib/touched');

ok(-f 't/dual/001_load.t');

append_file('t/dual/001_load.t', <<ENDS);
# \$t->ok_ht_userlist_r(make_url => 1, ht => {
# 		user_list => [ { ht_id => 1, name => 'admin' } ] });
# \$t->ok_ht_userform_r(make_url => 1, ht => {
#		                        username => '', password => '', });
ENDS

my $m_str2 = read_file('MANIFEST');
is($m_str2, $m_str);

$res = $mt->run_make_install;
is(-d "$td/inst/share/ttt", undef) or do {
#	diag($res);
#	diag("$td");
#readline(\*STDIN);
};

isnt(-d "$td/inst/share/perl", undef) or do {
##	diag($res);
#	diag("$td");
#readline(\*STDIN);
};

ok(-f $mt->install_dir . "/TTT.pm");
my $inst_path = $mt->install_dir . "/TTT";
ok(-f "$inst_path/Maker.pm");

chdir $td;
$mt->make_swit_project(root_class => 'MU');
$mt->install_subsystem('TheSub');

ok(require 'TTT/Maker.pm');

eval "use lib 'lib'";
isnt(-f 'lib/MU/TheSub.pm', undef) or do {
	diag($td);
#	readline(\*STDIN);
};
use_ok('HTML::Tested', qw(HT HTV));
is(require 'lib/MU/TheSub.pm', 1);
is(MU::TheSub->templates_dir, 'templates/thesub');

isnt(-f "t/dual/thesub/001_load.t", undef) or do {
	diag($td);
#	readline(\*STDIN);
};
like(read_file("t/dual/thesub/001_load.t"), qr/ht_id/);

undef $Apache::SWIT::Maker::Config::_instance;
$tree = Apache::SWIT::Maker::Config->instance;
$ind = $tree->{pages}->{"thesub/index"};
isnt($ind, undef) or diag(Dumper($tree));
is($ind->{entry_points}->{r}->{template}, 'templates/thesub/index.tt');
is($ind->{entry_points}->{r}->{foo}, 'boo')
	 or diag(Dumper($tree));
is($ind->{class}, 'MU::TheSub::UI::Index');
is(read_file('templates/thesub/index.tt'), 
		read_file('templates/index.tt'));

$mt->replace_in_file('conf/httpd.conf.in', 'PerlModule MU::TheSub',
	"<Perl>\nuse lib '$td/TTT/blib/lib'\n</Perl>\nPerlModule MU::TheSub");
`perl Makefile.PL && make 2>&1`;
like(read_file('t/T/Test.pm'), qr/\bthesub\/index/);
$mt->replace_in_file('t/dual/001_load.t', '=> 7', '=> 8');
append_file('t/dual/001_load.t', <<ENDT);
use lib '$td/TTT/blib/lib';
use MU::TheSub;
\$t->ok_ht_thesub_index_r(make_url => 1, ht => { first => '' });
ENDT
$res = join('', `make test 2>&1`);
unlike($res, qr/Error/) or do {
#	diag("here $td");
#	readline(\*STDIN);
};
like($res, qr/thesub\/001/);

chdir "$td/TTT";
$mt->insert_into_schema_pm('\$dbh->do("create table ttt_table (a text)")');
$mt->replace_in_file('lib/TTT/UI/Index.pm', "return \\\$", <<ENDM);
my \$arr = Apache::SWIT::DB::Connection->instance->db_handle
			->selectcol_arrayref("select a from ttt_table");
\$r->pnotes('SWITSession')->set_username(\$arr);
return \$
ENDM

$mt->replace_in_file('t/dual/001_load.t', '=> 3', '=> 5');
append_file('t/dual/001_load.t', <<ENDT);
can_ok(\$t->session, 'get_username');
\$t->ht_index_u(ht => {});
\$t->ok_ht_index_r(ht => { first => '' });
ENDT

$mt->replace_in_file('t/950_install.t', "TheSub'\\);", <<ENDM);
TheSub');
\$mt->install_subsystem_schema;
\$mt->install_session_base;
ENDM

$res = join('', `make test 2>&1`);
unlike($res, qr/Error/) or ASTU_Wait($td);

$mt->replace_in_file('t/dual/001_load.t', '=> 5', '=> 6');
append_file('t/dual/001_load.t', <<ENDT);
can_ok(\$t->session, 'get_mu_thesub');
ENDT
$res = join('', `make test_ TEST_FILES=t/950_install.t 2>&1`);
unlike($res, qr/Error/) or do {
#	diag($td);
#	readline(\*STDIN);
};

chdir '/';
