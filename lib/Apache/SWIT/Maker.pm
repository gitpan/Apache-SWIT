=head1 NAME

Apache::SWIT::Maker - creates various skeleton files for your SWIT project.

=head1 METHODS

=cut
use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker;
use base 'Class::Accessor';
use File::Path;
use File::Basename qw(dirname basename);
use YAML;
use File::Copy;
use Cwd qw(abs_path);
use Apache::SWIT::Maker::GeneratorsQueue;
use Apache::SWIT::Maker::FileWriterData;
use Apache::SWIT::Maker::Conversions;

__PACKAGE__->mk_accessors(qw(root_class root_location app_name root_var_name
			session_class lib_dir file_writer));

sub rf {
	my $file = shift;
	open(my $fh, $file) or die "Unable to open $file";
	my $mf_str = join('', <$fh>);
	close $fh;
	return $mf_str;
}

sub wf {
	my ($file, $content) = @_;
	open(my $fh, ">$file") or die "Unable to open $file";
	print $fh $content;
	close $fh;
}

sub wf_path {
	my ($f, $str) = @_;
	mkpath(dirname($f));
	wf($f, $str);
}

sub mani_wf {
	my ($f, $str) = @_;
	wf_path($f, $str);
	wf('>MANIFEST', "\n$f");
}

sub new {
	my $self = shift->SUPER::new(@_);
	$self->lib_dir("lib") unless $self->lib_dir;
	$self->{file_writer} ||= Apache::SWIT::Maker::FileWriterData->new;
	unless ($self->root_class) {
		my $mf_str = rf('Makefile.PL');
		my ($root_class) = ($mf_str =~ /NAME[^\n\']+\'([^\']+)/);
		die "Unable to get root_class from $mf_str" unless $root_class;
		$self->root_class($root_class);
	}
	unless ($self->session_class) {
		$self->session_class($self->root_class . "::Session");
	}
	unless ($self->root_location) {
		my $rl = lc("/" . $self->root_class);
		$rl =~ s/::/\//g;
		$self->root_location($rl);
	}
	unless($self->app_name) {
		my $app_name = $self->root_location;
		$app_name =~ s/\//_/g;
		$app_name =~ s/^_//;
		$self->app_name($app_name);
	}
	unless($self->root_var_name) {
		my $rvn = uc($self->root_class) . "_ROOT";
		$rvn =~ s/::/_/g;
		$self->root_var_name($rvn);
	}
	return $self;
}

sub schema_class { return shift()->root_class . '::DB::Schema'; }
sub connection_class { return shift()->root_class . '::DB::Connection'; }

sub initial_swit_yaml_tree {
	my $self = shift;
	return {
		root_class => $self->root_class, 
		root_location => $self->root_location,
		session_class => $self->session_class,
		pages => {},
		generators => [ 'Apache::SWIT::Maker::Generator' ],
	};
}

sub write_swit_yaml {
	my $self = shift;
	mani_wf('conf/swit.yaml', Dump($self->initial_swit_yaml_tree));
}

sub write_makefile_pl {
	my $self = shift;
	my $app_name = $self->app_name;
	my $mf_str = rf('Makefile.PL');
	my $more = $self->makefile_install_string;
	wf('Makefile.PL', <<ENDM . $more);
package MY;
use Apache::SWIT::Maker;

$mf_str

sub test {
	my \$res = shift()->SUPER::test(\@_);
	\$res =~ s/PERLRUN\\)/PERLRUN) -I t\\//g;
	return \$res;
}

sub postamble { return Apache::SWIT::Maker->get_makefile_rules . q{
test :: test_direct test_apache 

APACHE_TEST_FILES = `find t/dual -name "*.t" | sort`

test_direct :: pure_all
	PERL_DL_NONLAZY=1 \$(FULLPERLRUN) -I t -I blib/lib t/direct_test.pl \$(APACHE_TEST_FILES)

test_apache :: pure_all
	\$(RM_F) t/logs/access_log  t/logs/error_log
	ulimit -c unlimited && PERL_DL_NONLAZY=1 \$(FULLPERLRUN) -I t -I blib/lib t/apache_test.pl \$(APACHE_TEST_FILES)

realclean ::
	\$(RM_RF) t/htdocs t/logs
	\$(RM_F) t/conf/apache_test_config.pm  t/conf/modperl_inc.pl t/T/Test.pm
	\$(RM_F) t/conf/extra.conf t/conf/httpd.conf t/conf/modperl_startup.pl
	\$(RM_F) conf/httpd.conf t/conf/my.conf
}}
ENDM
}

sub makefile_constants_string {
	my $app_name = shift()->app_name;
	return <<ENDM;
sub constants {
	my \$str = shift()->SUPER::constants(\@_);
	\$str =~ s#INSTALLSITELIB[^\\n]+#INSTALLSITELIB = \\\$(SITEPREFIX)/share\/$app_name#;
	return \$str;
}
ENDM
}

sub makefile_install_string {
	my $self = shift;
	my $app_name = $self->app_name;
	return $self->makefile_constants_string . <<ENDM;
sub install {
	return <<ENDS;
install :: all 
	mkdir -p \\\$(INSTALLSITELIB)/conf
	cp -a \\\$(INST_LIB) \\\$(INSTALLSITELIB)
	perl -p -e \\"s#\\\\\\\@ServerRoot\\\\@#\\\$(INSTALLSITELIB)#g\\" < conf/httpd.conf > \\\$(INSTALLSITELIB)/conf/httpd.conf
	cp -a templates \\\$(INSTALLSITELIB)
ENDS
}
ENDM
}

sub write_pm_file {
	my ($self, $module_class, $str, $no_manifest) = @_;
	my $module_file = $self->lib_dir . "/$module_class.pm";
	$module_file =~ s/::/\//g;
	wf_path($module_file, <<ENDM);
use strict;
use warnings FATAL => 'all';

package $module_class;
$str

1;
ENDM
	wf('>MANIFEST', "\n$module_file") unless $no_manifest;
}

sub add_class { 
	my ($self, $new_class, $str) = @_;
	my $rc = $self->root_class;
	$new_class = $rc . "::$new_class" if ($new_class !~ /^$rc\::/);
	$self->write_pm_file($new_class, $str || "");
}

sub write_session_pm {
	my $self = shift;
	my $an = $self->app_name;
	my $sess_dir = "/tmp/$an\_sessions";
	$self->add_class($self->session_class, <<ENDM);
use base 'Apache::SWIT::Session';

sub cookie_name { return '$an'; }

ENDM
}

sub db_env_var {
	my $db_var = shift->root_var_name;
	$db_var =~ s/ROOT$/DB/;
	return $db_var;
}

sub write_db_connection_pm {
	my $self = shift;
	my $db_var = $self->db_env_var;
	$db_var =~ s/_DB$//;
	$self->write_pm_file($self->connection_class, <<ENDM);
use base 'Apache::SWIT::DB::Connection';
__PACKAGE__->AppName('$db_var');
ENDM
}

sub write_db_schema_file {
	my $self = shift;
	my $an = $self->app_name;
	$self->write_pm_file($self->schema_class, <<ENDM);
use base 'DBIx::VersionedSchema';
__PACKAGE__->Name('$an');

__PACKAGE__->add_version(sub {
	my \$dbh = shift;
});

ENDM
}

sub with_lib_dir {
	my ($self , $new_ld, $func) = @_;
	my $ld = $self->lib_dir;
	$self->lib_dir($new_ld);
	$func->();
	$self->lib_dir($ld);
}

sub write_test_db_file {
	my $self = shift;
	my $sc = $self->schema_class;
	my $an = $self->app_name;
	my $db_var = $self->db_env_var;
	my $conn = $self->connection_class;
	$self->with_lib_dir('t', sub {
		$self->write_pm_file('T::TempDB', <<ENDM);
use Test::TempDatabase;
use $sc;
use $conn;

\$ENV{$db_var\_NAME} = '$an\_test_db';
our \$test_db = Test::TempDatabase->create(
			dbname => '$an\_test_db',
                        schema => '$sc', dbi_args => $conn\->DBIArgs);
$conn\->instance(\$test_db->handle);
END { \$test_db->destroy; }
ENDM
	});
}

sub write_t_extra_conf_in {
	my $self = shift;
	my $an = $self->app_name;
	my $db_var = $self->db_env_var;
	mani_wf('t/conf/extra.conf.in', <<ENDM);
PerlSetEnv $db_var\_NAME $an\_test_db
Include conf/my.conf
ENDM
}

sub more_stuff_in_httpd_conf_in { return 'PerlModule @SessionClass@'; }

sub write_httpd_conf_in {
	my $self = shift;
	my $root_location = $self->root_location;
	my $more = $self->more_stuff_in_httpd_conf_in;
	my $app_name = $self->app_name;
	mani_wf('conf/httpd.conf.in', sprintf(<<ENDM
PerlSetEnv %s \@ServerRoot\@
<Perl>
	use lib '\@ServerRoot\@/lib';
</Perl>

$more
<Location $root_location>
	PerlSetVar SWITRoot \@ServerRoot\@/
	PerlAccessHandler \@SessionClass\@\->access_handler
	PerlSetVar SWITSessionsDir /tmp/$app_name-sessions
</Location>
ENDM
		, $self->root_var_name));

}

sub write_apache_test_pl {
	mani_wf('t/apache_test.pl', <<ENDM);
use T::TempDB;
do "t/apache_test_run.pl";
ENDM
}

sub write_apache_test_run_pl {
	mani_wf('t/apache_test_run.pl', <<ENDM);
use Apache::SWIT::Test::Apache;
Apache::SWIT::Test::Apache::Run('my.conf', 'my.conf');
ENDM
}

sub t_dbi_base_class { return shift()->root_class . "::DB::Base"; }

sub use_ok_in_010_db_t { return shift()->root_class; }

sub add_test {
	my ($self, $file, $number, $content) = @_;
	unless ($number) {
		$number = 1;
		$content = "BEGIN { use_ok('" . $self->root_class ."'); }";
	}
	mani_wf($file, <<ENDT);
use strict;
use warnings FATAL => 'all';

use Test::More tests => $number;

$content
ENDT
}

sub write_010_db_t {
	my $self = shift;
	my $rc = $self->root_class;
	my $more_uses = $self->use_ok_in_010_db_t;
	my $conn = $self->connection_class;
	my $t_dbi_base = $self->t_dbi_base_class;
	$self->add_test('t/010_db.t', 4, <<ENDM);
use T::TempDB;

BEGIN { use_ok('$rc\::DB::Base'); 
	use_ok('$conn');
	use_ok('$more_uses');
}

package T::DBI;
use base '$t_dbi_base';
__PACKAGE__->table('test_table');
__PACKAGE__->columns(Essential => qw/a b/);

package main;
$conn->instance->db_handle->do("create table test_table (a integer, b text)");
is_deeply([ T::DBI->retrieve_all ], []);

ENDM
}

sub db_base_pm_connection { return shift()->connection_class; }

sub write_swit_app_pl {
	my $self = shift;
	$self->file_writer->write_scripts_swit_app_pl({
				class => ref($self) });
	chmod 0755, 'scripts/swit_app.pl';
}

sub write_initial_files {
	my $self = shift;

	$self->write_swit_yaml;
	$self->write_session_pm;
	$self->write_db_schema_file;
	$self->write_test_db_file;
	$self->write_db_connection_pm;
	$self->write_t_extra_conf_in;
	$self->write_httpd_conf_in;
	$self->file_writer->write_dual_test("001_load", 1
		, "\$t->ok_ht_index_r(make_url => 1, "
			. "ht => { first => '' });\n"
		, $self->dual_use_ok_class);
	$self->file_writer->write_t_direct_test_pl;
	$self->write_apache_test_run_pl;
	$self->write_apache_test_pl;
	$self->file_writer->write_conf_makefile_rules_yaml;
	$self->write_makefile_pl;
	$self->file_writer->write_db_base_pm({
			connection => $self->db_base_pm_connection
	}, { class => $self->root_class . "::DB::Base" });
	$self->write_010_db_t;
	$self->write_swit_app_pl;
	$self->add_ht_page('Index');
}

sub _create_new_entry {
	my ($self, $page_class) = @_;
	my $tree = YAML::LoadFile('conf/swit.yaml') 
			or die "No conf/swit.yaml found";
	my $full_class = conv_make_full_class(
				$tree->{root_class}, "UI", $page_class);

	my $entry_point = lc($page_class);
	$entry_point =~ s/::/\//g;
	my $tt_file = "templates/$entry_point.tt";
	my $entry = {
		class => $full_class,
		entry_points => {
			r => {
				template => $tt_file,
				handler => 'swit_render_handler',
			},
			u => {
				handler => 'swit_update_handler',
			},
		},
	};
	$tree->{pages}->{$entry_point} = $entry;
	$self->dump_yaml_conf($tree);
	return $entry;
}

=head2 add_page(page)

Adds page and related files. Page should be the name of the module, 
e.g. 'Index'. See C<add_ht_page> for adding HTML::Tested enabled page.

=cut
sub add_page {
	my ($self, $page_class, $tmpl_str) = @_;
	my $e = $self->_create_new_entry($page_class);
	$self->file_writer->write_tt_file({}, {
			path => $e->{entry_points}->{r}->{template} });
	$self->write_pm_file($e->{class}, <<ENDM);
use base qw(Apache::SWIT);

sub swit_render {
	my (\$class, \$req) = \@_;
	my \$res = {};
	return \$res;
}
ENDM
	return $e;
}

sub ht_root_class_name {
	my ($self, $entry) = @_;
	return "'" . $entry->{class} . "::Root'";
}

=head2 add_ht_page(page)

Adds HTML::Tested enabled page and related files. 
Page should be the name of the module, e.g. 'Index'.

=cut
sub add_ht_page {
	my ($self, $page_class) = @_;
	my $p = $self->_create_new_entry($page_class);
	$self->file_writer->write_tt_file({ content => '[% first %]' }, {
			path => $p->{entry_points}->{r}->{template} });
	$self->file_writer->write_ht_page_pm({
		full_class => $p->{class},
		ht_root => $self->ht_root_class_name($p)
	}, { path => "lib/" . $p->{class} . ".pm" });
	return $p;
}

sub alias_class { return $_[1]; }
sub dual_use_ok_class { return shift()->root_class . "::UI::Index"; }

sub load_yaml_conf {
	return YAML::LoadFile('conf/swit.yaml') 
			or die "No conf/swit.yaml found";
}

sub dump_yaml_conf {
	YAML::DumpFile('conf/swit.yaml', $_[1]);
}

sub session_class_for_httpd_conf {
	return $_[1]->{session_class};
}

sub httpd_location_section {
	my ($self, $gq, $loc, $entry) = @_;
	my $res = $gq->run('location_section_prolog', $loc, $entry);
	my $l = $gq->tree->{root_location} . "/$loc";
	while (my ($n, $v) = each %{ $entry->{entry_points} }) {
		$res .= "<Location $l/$n>\n";
		$res .= "\tSetHandler perl-script\n";
		$res .= "\tPerlHandler $entry->{class}\->$v->{handler}\n";
		$res .= $gq->run('location_section_contents', $n, $v);
		$res .= "</Location>\n";
	}
	$res .= ($gq->run('location_section_epilogue', $loc, $entry) || '');
	return $res;
}

sub regenerate_httpd_conf {
	my $self = shift;
	my $gq = Apache::SWIT::Maker::GeneratorsQueue->new;
	my $tree = $gq->tree;
	my $ht_in = $gq->run('httpd_conf_start');
	my $sess_class = $self->session_class_for_httpd_conf($tree);

	my $aliases = "";
	my $rl = $tree->{root_location};

	while (my ($n, $v) = each %{ $tree->{pages} }) {
		$ht_in .= $self->httpd_location_section($gq, $n, $v) . "\n";
		$aliases .= "\"$n\" => '"
				. $self->alias_class($v->{class}) . "',\n";
	}

	wf('conf/httpd.conf', $ht_in);
	my $ap = abs_path('.');
	$ht_in =~ s/\@ServerRoot\@\/lib/$ap\/blib\/lib/g;
	$ht_in =~ s/\@ServerRoot\@/$ap/g;
	wf('t/conf/my.conf', $ht_in);

	$self->with_lib_dir('t', sub {
		$self->write_pm_file('T::Test', <<ENDS, 1);
use base 'Apache::SWIT::Test';
use $tree->{session_class};

__PACKAGE__->root_location('$rl');
__PACKAGE__->make_aliases(
$aliases
);

sub new {
	my (\$class, \$args) = \@_;
	\$args->{session_class} = '$sess_class'
		unless exists(\$args->{session_class});
	return \$class->SUPER::new(\$args);
}

1;
ENDS
	});
	return $tree;
}

sub remove_file {
	my ($self, $file) = @_;
	unlink($file);
	open(my $fh, 'MANIFEST');
	my @lines = grep { !(/$file/) } <$fh>;
	close $fh;
	wf('MANIFEST', join("", @lines));
}

=head2 remove_page(page)

Removes page and related files. Page is relative to the root location

=cut
sub remove_page {
	my ($class, $page) = @_;
	my $tree = $class->load_yaml_conf;
	my $ep = lc($page);
	$ep =~ s/::/\//g;
	my $p = delete $tree->{pages}->{$ep} or die "Unable to find $page";
	my $module_file = "lib/" . $p->{class} . ".pm";
	$module_file =~ s/::/\//g;
	$class->remove_file($module_file);
	$class->remove_file($p->{entry_points}->{r}->{template});
	YAML::DumpFile('conf/swit.yaml', $tree);
}

sub get_makefile_rules {
	my $rules = YAML::LoadFile('conf/makefile_rules.yaml')
		or die "No makefile rules found";
	my $res = "";
	for my $r (@$rules) {
		$res .= join(' ',  @{ $r->{targets} }) . " :: ";
		$res .= join(' ', @{ $r->{dependencies} }) . "\n\t";
		$res .= join("\n\t", @{ $r->{actions} }) . "\n\n";
	}
	return $res;
}

sub add_db_class {
	my ($self, $table) = @_;
	my $ct = conv_table_to_class($table);
	my $c = $self->root_class . "::DB::" . $ct;
	$self->file_writer->write_db_pm({ class => $c, table => $table
			, root => $self->root_class }
			, { path =>  "lib/$c.pm" });
	return $ct;
}

sub _extract_columns {
	my ($self, $c) = @_;
	push @INC, "t", "lib";
	eval "use T::TempDB";
	die "Cannot use T::TempDB: $@" if $@;
	eval "use $c";
	die "Cannot use $c: $@" if $@;
	my %pc = map { ($_, 1) } $c->primary_columns;
	return grep { !$pc{$_} } $c->columns;
}

sub scaffold {
	my ($self, $table) = @_;
	my $ct = $self->add_db_class($table);
	my $db_class = $self->root_class . "::DB::$ct";

	my @cols = $self->_extract_columns($db_class);
	my $tt_cols = join("\n", map { "[% $_ %]" } @cols);

	my $le = $self->_create_new_entry("$ct\::List");
	$self->file_writer->write_tt_file({ 
		content => "[% FOREACH $table\_list %]\n$tt_cols\n[% END %]"
	}, { path => $le->{entry_points}->{r}->{template} });
	$self->file_writer->write_list_ht_page_pm({
		full_class => $le->{class},
		fields => [ map { { field => $_ } } @cols ],
		db_class => $db_class,
		list_name => "$table\_list",
	}, { path => "lib/" . $le->{class} . ".pm" });

	my $fe = $self->_create_new_entry("$ct\::Form");
	$self->file_writer->write_tt_file({ content => $tt_cols }, {
			path => $fe->{entry_points}->{r}->{template} });
	$self->file_writer->write_form_ht_page_pm({
		full_class => $fe->{class},
		db_class => $db_class,
		fields => [ map { { field => $_ } } @cols ],
	}, { path => "lib/" . $fe->{class} . ".pm" });

	my ($lt, $ft) = map { lc($ct) . "_$_" } qw(list form);

	my $cols99 = join(",\n\t", map { "$_ => '99'" } @cols);
	my $form_ok_test = "\$t->ok_ht_$ft\_r(make_url => 1, ht => {\n\t"
		. join(",\n\t", map { "$_ => ''" } @cols) . "\n});\n"
		. "\$t->ht_$ft\_u(ht => {\n\t$cols99\n});";

	$self->file_writer->write_dual_test(
			conv_next_dual_test(rf('MANIFEST')) . "_$table", 2
			, <<ENDC, map { $_->{class} } ($le, $fe));
$form_ok_test
\$t->ok_ht_$lt\_r(make_url => 1, ht => { $table\_list => [ {
	ht_id => 1, $cols99
} ] });
ENDC
}

1;
