use strict;
use warnings FATAL => 'all';

use Test::More tests => 58;
use Data::Dumper;
use File::Slurp;
use File::Temp qw(tempdir);

BEGIN {
	use_ok('Apache::SWIT::Maker::Skeleton');
	use_ok('Apache::SWIT::Maker::Skeleton::Scaffold::DualTest');
	use_ok('Apache::SWIT::Maker::Skeleton::Scaffold::List');
	use_ok('Apache::SWIT::Maker::Skeleton::Scaffold::ListTemplate');
	use_ok('Apache::SWIT::Maker::Skeleton::Scaffold::Info');
	use_ok('Apache::SWIT::Maker::Skeleton::ApacheTest');
	use_ok('Apache::SWIT::Maker::Skeleton::ApacheTestRun');
	use_ok('Apache::SWIT::Subsystem::Skeleton::PageClasses');
	use_ok('Apache::SWIT::Maker');
};

my $dut = Apache::SWIT::Maker::Skeleton::Scaffold::DualTest->new({
		columns => [ qw(col_a col_b col_c) ], table => 'the_tab' });
ok($dut);
is_deeply($dut->columns, [ qw(col_a col_b col_c) ]);
is($dut->table, 'the_tab');
is($dut->empty_cols_v, "col_a => '',\n\tcol_b => '',\n\tcol_c => ''");
is($dut->cols_99_v, "col_a => '99',\n\tcol_b => '99',\n\tcol_c => '99'");
is($dut->cols_333_v, "col_a => '333',\n\tcol_b => '333',\n\tcol_c => '333'");
is($dut->table_class_v, "TheTab");
is($dut->form_test_v, "thetab_form");
is($dut->info_test_v, "thetab_info");
is($dut->list_test_v, 'thetab_list');
is($dut->list_name_v, 'the_tab_list');
is($dut->cols_99_list_v, "col_b => '99',\n\tcol_c => '99',");
is($dut->cols_333_list_v, "col_b => '333',\n\tcol_c => '333',");
is($dut->col1_v, "col_a");
is_deeply($dut->columns, [ qw(col_a col_b col_c) ]);

my $td = tempdir('/tmp/pltemp_400_XXXXXX', CLEANUP => 1);
chdir $td;

write_file('Makefile.PL', "NAME => 'Aaa::Bbb'\n");
is(Apache::SWIT::Maker::Config->instance->root_class, 'Aaa::Bbb');
is($dut->root_class_v, 'Aaa::Bbb');

my $gtv = $dut->get_template_vars;
is_deeply($gtv, { map { ($_ => $dut->$_) } qw(
	form_test_v info_test_v
	empty_cols_v
	cols_99_v cols_333_v
	cols_99_list_v cols_333_list_v
	col1_v root_class_v table_class_v
	list_name_v list_test_v
) }) or diag(Dumper($gtv));

is($dut->get_output, <<'ENDS');
use strict;
use warnings FATAL => 'all';

use Test::More tests => 16;

BEGIN {
	use_ok('T::Test');
	use_ok('Aaa::Bbb::UI::TheTab::List');
	use_ok('Aaa::Bbb::UI::TheTab::Form');
	use_ok('Aaa::Bbb::UI::TheTab::Info');
};

my $t = T::Test->new;
$t->ok_ht_thetab_form_r(make_url => 1, ht => {
	col_a => '',
	col_b => '',
	col_c => ''
});
$t->ht_thetab_form_u(ht => {
	col_a => '99',
	col_b => '99',
	col_c => '99'
});
$t->ok_ht_thetab_list_r(make_url => 1, ht => { the_tab_list => [ {
	col_b => '99',
	col_c => '99', HT_SEALED_col_a => [ '99', 1 ],
} ] });
$t->ok_follow_link(text => '99');
$t->ok_ht_thetab_info_r(param => { HT_SEALED_edit_link => 1 }, ht => {
	col_a => '99',
	col_b => '99',
	col_c => '99', HT_SEALED_edit_link => [ 1 ],
});

$t->ok_follow_link(text => 'Edit');
$t->ok_ht_thetab_form_r(param => { HT_SEALED_ht_id => 1 }, ht => {
	col_a => '99',
	col_b => '99',
	col_c => '99'
});

$t->ht_thetab_form_u(ht => {
	col_a => '333',
	col_b => '333',
	col_c => '333', HT_SEALED_ht_id => 1,
});
$t->ok_follow_link(text => 'List all entries');
$t->ok_ht_thetab_list_r(ht => { the_tab_list => [ {
	col_b => '333',
	col_c => '333', HT_SEALED_col_a => [ '333', 1 ],
} ] });

$t->ok_follow_link(text => '333');
$t->ok_follow_link(text => 'Edit');
$t->ok_ht_thetab_form_r(param => { HT_SEALED_ht_id => 1 }, ht => {
	col_a => '333',
	col_b => '333',
	col_c => '333', HT_SEALED_ht_id => 1, delete_button => 'Delete',
});
$t->ht_thetab_form_u(button => [ delete_button => 'Delete' ], ht => {
	col_a => '333',
	col_b => '333',
	col_c => '333', HT_SEALED_ht_id => 1,
});

$t->ok_ht_thetab_list_r(make_url => 1, ht => { the_tab_list => [] });
ENDS

$dut->columns([ 'one' ]);
is($dut->cols_99_list_v, '');

Apache::SWIT::Maker::Skeleton::ApacheTest->new->write_output;
is(read_file('t/apache_test.pl'), <<ENDM);
use T::TempDB;
do "t/apache_test_run.pl";
ENDM
like(read_file('MANIFEST'), qr/apache_test/);

Apache::SWIT::Maker::Skeleton::ApacheTestRun->new->write_output;
like(read_file('MANIFEST'), qr/apache_test_run/);

append_file('MANIFEST', "\nt/dual/012_test.t\n");
is($dut->output_file, "t/dual/022_the_tab.t");

Apache::SWIT::Maker::Config->instance->create_new_page('Aaa::Bbb::Go');
is_deeply(Apache::SWIT::Maker::Config->instance->pages, {
go => {
	entry_points => {
		u => { handler => 'swit_update_handler' },
		r => {
                	handler => 'swit_render_handler',
			template => 'templates/go.tt'
		}
	}, class => 'Aaa::Bbb::Go' }
}) or diag(Dumper(Apache::SWIT::Maker::Config->instance->pages));

# We should not save becouse transaction can fail
ok(! -f 'conf/swit_app.yaml');

my $list = Apache::SWIT::Maker::Skeleton::Scaffold::List->new({
		columns => [ qw(col_a col_b col_c) ], table => 'the_tab' });
ok($list);
ok($list->columns);
ok($list->table);
ok($list->can('config_entry'));

my $e = Apache::SWIT::Maker::Config->instance->create_new_page('P');
is_deeply($e, {
	entry_points => {
		u => { handler => 'swit_update_handler' },
		r => {
                	handler => 'swit_render_handler',
			template => 'templates/p.tt'
		}
}, class => 'Aaa::Bbb::UI::P' }) or diag(Dumper($e));
$list->config_entry($e);

my $res = $list->get_output;
is($res, <<'ENDS');
use strict;
use warnings FATAL => 'all';

package Aaa::Bbb::UI::P::Root::Item;
use base 'HTML::Tested::ClassDBI';
use Aaa::Bbb::DB::TheTab;
__PACKAGE__->make_tested_link('col_a'
		, href_format => '../info/r?edit_link=%s'
		, cdbi_bind => [ col_a => 'Primary' ]
		, column_title => 'ColA');
__PACKAGE__->make_tested_marked_value('col_b'
		, cdbi_bind => '', column_title => 'ColB');
__PACKAGE__->make_tested_marked_value('col_c'
		, cdbi_bind => '', column_title => 'ColC');

__PACKAGE__->bind_to_class_dbi('Aaa::Bbb::DB::TheTab');

package Aaa::Bbb::UI::P::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_form('form', default_value => 'u');
__PACKAGE__->make_tested_list('the_tab_list', __PACKAGE__ . '::Item');

package Aaa::Bbb::UI::P;
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->the_tab_list_containee_do(query_class_dbi => 'retrieve_all');
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
ENDS

$list->write_output;
is(read_file('lib/Aaa/Bbb/UI/P.pm'), $res);

my $args = { columns => [ qw(col_a col_b col_c) ], table => 'the_tab' };
my $lt = Apache::SWIT::Maker::Skeleton::Scaffold::ListTemplate->new($args);
$lt->config_entry($e);
$lt->write_output;
is(read_file('templates/p.tt'), <<'ENDS');
<html>
<body>
[% form %]
[% the_tab_list_table %]
</form>
</body>
</html>
ENDS

Apache::SWIT::Maker->write_swit_yaml;
ok(-f 'conf/swit.yaml');

Apache::SWIT::Maker->_make_page('Info', $args
		, qw(scaffold_info scaffold_info_template));
ok(-f 'lib/Aaa/Bbb/UI/Info.pm');
ok(-f 'templates/info.tt');

is(read_file('lib/Aaa/Bbb/UI/Info.pm'), <<'ENDS');
use strict;
use warnings FATAL => 'all';

package Aaa::Bbb::UI::Info::Root;
use base 'HTML::Tested::ClassDBI';
use Aaa::Bbb::DB::TheTab;
__PACKAGE__->make_tested_form(form => default_value => u => children => [
	col_a => marked_value => { cdbi_bind => '' },
	col_b => marked_value => { cdbi_bind => '' },
	col_c => marked_value => { cdbi_bind => '' },
]);
__PACKAGE__->make_tested_link('edit_link'
		, href_format => '../form/r?ht_id=%s'
		, caption => 'Edit', cdbi_bind => [ 'Primary' ]);
__PACKAGE__->bind_to_class_dbi('Aaa::Bbb::DB::TheTab');

package Aaa::Bbb::UI::Info;
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->cdbi_load;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
ENDS

is(read_file('templates/info.tt'), <<ENDS);
<html>
<body>
[% form %]
ColA: [% col_a %] <br />
ColB: [% col_b %] <br />
ColC: [% col_c %] <br />
</form>
[% edit_link %]
</body>
</html>
ENDS

Apache::SWIT::Maker->_make_page('Form', $args
		, qw(scaffold_form scaffold_form_template));
ok(-f 'lib/Aaa/Bbb/UI/Form.pm');
is(read_file('lib/Aaa/Bbb/UI/Form.pm'), <<'ENDS');
use strict;
use warnings FATAL => 'all';

package Aaa::Bbb::UI::Form::Root;
use base 'HTML::Tested::ClassDBI';
use Aaa::Bbb::DB::TheTab;
__PACKAGE__->make_tested_hidden('ht_id', cdbi_bind => 'Primary');
__PACKAGE__->make_tested_submit('submit_button', default_value => 'Submit');
__PACKAGE__->make_tested_submit('delete_button', default_value => 'Delete');
__PACKAGE__->make_tested_form(form => default_value => u => children => [
	col_a => edit_box => { cdbi_bind => '' },
	col_b => edit_box => { cdbi_bind => '' },
	col_c => edit_box => { cdbi_bind => '' },
]);
__PACKAGE__->bind_to_class_dbi('Aaa::Bbb::DB::TheTab');
__PACKAGE__->load_db_constraints;

package Aaa::Bbb::UI::Form;
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->cdbi_load;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	$root->delete_button
		? $root->cdbi_delete
		: $root->cdbi_create_or_update;
	return "r";
}

1;
ENDS

ok(-f 'templates/form.tt');
is(read_file('templates/form.tt'), <<'ENDS');
<html>
<body>
<h2>Add/Remove/Edit TheTab</h2>
[% form %]
ColA: [% col_a %] <br />
ColB: [% col_b %] <br />
ColC: [% col_c %] <br />
[% ht_id %]
[% submit_button %]
[% delete_button %]
<br />
<a href="../list/r">List all entries</a>
</form>
</body>
</html>
ENDS

my $pc = Apache::SWIT::Subsystem::Skeleton::PageClasses->new;
ok($pc);

$pc->add("Aaa::Bbb::CCC");
is_deeply(Apache::SWIT::Maker::Config->instance->{classes_for_inheritance}
		, [ "Aaa::Bbb::CCC" ]);
like(read_file('conf/swit.yaml'), qr/CCC/);

$pc->write_output;
ok(-f 'blib/lib/Aaa/Bbb/PageClasses.pm');
is(read_file('blib/lib/Aaa/Bbb/PageClasses.pm'), <<'ENDS');
use strict;
use warnings FATAL => 'all';

package Aaa::Bbb::PageClasses;
use base 'Apache::SWIT::Subsystem::Base';

sub classes_for_inheritance { return qw(
	UI::Info
	UI::P
	UI::Form
	Go
	CCC
); }

1;
ENDS

unlike(read_file('MANIFEST'), qr/PageClasses/);

chdir '/';
