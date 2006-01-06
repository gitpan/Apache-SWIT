use strict;
use warnings FATAL => 'all';

use Test::More tests => 37;
use File::Temp qw(tempdir);
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
is(-f './lib/TTT/DB/Connection.pm', undef);
isnt(-f './t/T/TTT/DB/Connection.pm', undef);
is(-f './t/001_load.t', undef);
unlike(Apache::SWIT::Maker::rf('lib/TTT/DB/Base.pm'), qr/Connection/);
like(Apache::SWIT::Maker::rf('Makefile.PL'),
	       	qr/TTT[^\']+write_installation_content_pm/);

Apache::SWIT::Subsystem::Maker->new->write_pm_file('TTT::DB::Random', <<ENDF);
sub number { return 494; }
ENDF

$mt->replace_in_file('lib/TTT.pm', '__PACKAGE__', '__PACKAGE__, "DB::Random"');
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

open(my $fh, ">t/555_test.t") or die "Unable to open 555_test";
print $fh <<ENDT;
use Test::More tests => 12;
BEGIN { use_ok('T::TTT'); }
is(T::TTT->connection_class, "T::TTT::DB::Connection");
can_ok(T::TTT->connection_class, "instance");
is(T::TTT::DB::Random->number, 494);
is(T::TTT->db_random_class, 'T::TTT::DB::Random');
is(T::TTT::DB::Random->main_subsystem_class, 'T::TTT');
is(T::TTT::UI::Index->main_subsystem_class, 'T::TTT');
is(T::TTT->ui_index_root_class, 'TTT::UI::Index::Root');
is(T::TTT->ui_index_template, 'index.tt');
is(T::TTT->templates_dir, 'templates/');
is(T::TTT::Session->cookie_name, 'ttt');
can_ok(T::TTT::Session, 'get_t_ttt');
ENDT
close $fh;

`perl Makefile.PL && make 2>&1`;
my $ht_conf = Apache::SWIT::Maker::rf('conf/httpd.conf');
like($ht_conf, qr/T::TTT::UI::Index/);
like($ht_conf, qr/T::TTT::Session/);

my $ind_str = Apache::SWIT::Maker::rf('lib/TTT/UI/Index.pm');
unlike($ind_str, qr/\.tt/);
unlike($ind_str, qr/ht_root.+Root/);

my $m_str = Apache::SWIT::Maker::rf('MANIFEST');
unlike($m_str, qr/Test\.pm/);
unlike($m_str, qr/PageClasses\.pm/);

my $res = join('', `make test 2>&1`);
unlike($res, qr/Error/) or do {
#diag("$td");
#	readline(\*STDIN);
};
like($res, qr/950_install/);
Apache::SWIT::Maker::wf('>t/dual/001_load.t', <<ENDS);
# \$t->ok_ht_userlist_r(make_url => 1, ht => {
# 		user_list => [ { ht_id => 1, name => 'admin' } ] });
# \$t->ok_ht_userform_r(make_url => 1, ht => {
#		                        username => '', password => '', });
ENDS

my $m_str2 = Apache::SWIT::Maker::rf('MANIFEST');
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
is(require 'lib/MU/TheSub.pm', 1);
is(MU::TheSub->connection_class, 'MU::DB::Connection');
is(MU::TheSub->templates_dir, 'templates/thesub');
ok(-f "t/dual/thesub/001_load.t");
like(Apache::SWIT::Maker::rf("t/dual/thesub/001_load.t"), qr/ht_id/);

my $tree = Apache::SWIT::Maker->load_yaml_conf;
my $ind = $tree->{pages}->{"thesub/index"};
isnt($ind, undef) or diag(Dumper($tree));
is($ind->{location}, '/mu/thesub/index');
is($ind->{template}, 'templates/thesub/index.tt');
is($ind->{class}, 'MU::TheSub::UI::Index');
is(Apache::SWIT::Maker::rf('templates/thesub/index.tt'), 
		Apache::SWIT::Maker::rf('templates/index.tt'));

$mt->replace_in_file('conf/httpd.conf.in', 'PerlModule MU::TheSub',
	"<Perl>\nuse lib '$td/TTT/blib/lib'\n</Perl>\nPerlModule MU::TheSub");
`perl Makefile.PL && make 2>&1`;
like(Apache::SWIT::Maker::rf('t/T/Test.pm'), qr/\bthesub\/index/);
$mt->replace_in_file('t/dual/001_load.t', '=> 2', '=> 3');
Apache::SWIT::Maker::wf('>t/dual/001_load.t', <<ENDT);
use lib '$td/TTT/blib/lib';
use MU::TheSub;
\$t->ok_ht_thesub_index_r(base_url => "/mu/thesub/index/r", 
		ht => { first => '' });
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
my \$arr = \$class->main_subsystem_class->connection_class
			->instance->db_handle->selectcol_arrayref(
		"select a from ttt_table");
\$r->pnotes('SWITSession')->set_username(\$arr);
return \$
ENDM

$mt->replace_in_file('t/dual/001_load.t', '=> 2', '=> 3');
Apache::SWIT::Maker::wf('>t/dual/001_load.t', <<ENDT);
can_ok(\$t->session, 'get_username');
ENDT

$mt->replace_in_file('t/950_install.t', "TheSub'\\);", <<ENDM);
TheSub');
\$mt->install_subsystem_schema;
\$mt->install_session_base;
ENDM

$res = join('', `make test 2>&1`);
unlike($res, qr/Error/) or do {
#	diag($td);
#	readline(\*STDIN);
};

$mt->replace_in_file('t/dual/001_load.t', '=> 3', '=> 4');
Apache::SWIT::Maker::wf('>t/dual/001_load.t', <<ENDT);
can_ok(\$t->session, 'get_mu_thesub');
ENDT
$res = join('', `make test_ TEST_FILES=t/950_install.t 2>&1`);
unlike($res, qr/Error/) or do {
#	diag($td);
#	readline(\*STDIN);
};

chdir '/';
