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

__PACKAGE__->mk_accessors(qw(root_class root_location app_name root_var_name
			session_class lib_dir));

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
	wf('>MANIFEST', "$f\n");
}

sub new {
	my $self = shift->SUPER::new(@_);
	$self->lib_dir("lib") unless $self->lib_dir;
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

sub write_swit_yaml {
	my $self = shift;
	mani_wf('conf/swit.yaml', sprintf(<<ENDM
root_class: %s
root_location: "%s"
session_class: %s
pages: {}
ENDM
		, $self->root_class, $self->root_location, $self->session_class));
}

sub write_makefile_rules_yaml {
	mani_wf('conf/makefile_rules.yaml', <<ENDS);
- target: config
  dependencies: 
    - t/conf/httpd.conf
    - conf/httpd.conf
  actions:
    - \$(NOECHO) \$(NOOP)
- target: t/conf/httpd.conf
  dependencies: 
    - t/conf/extra.conf.in
  actions:
    - PERL_DL_NONLAZY=1 \$(FULLPERLRUN) t/apache_test_run.pl -config
- target: conf/httpd.conf
  dependencies:
    - conf/swit.yaml
    - conf/httpd.conf.in
  actions:
    - ./scripts/swit_app.pl regenerate_httpd_conf
ENDS
}

sub write_makefile_pl {
	my $self = shift;
	my $app_name = $self->app_name;
	my $mf_str = rf('Makefile.PL');
	wf('Makefile.PL', <<ENDM . $self->makefile_install_string);
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

APACHE_TEST_FILES = `find t/dual -name "*.t"`

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

sub makefile_install_string {
	my $app_name = shift()->app_name;
	return <<ENDM;
sub install {
	return <<ENDS;
install :: all 
	mkdir -p \\\$(SITEPREFIX)/share/$app_name/conf
	cp -a \\\$(INST_LIB) \\\$(SITEPREFIX)/share/$app_name
	perl -p -e \\"s#\\\\\\\@ServerRoot\\\\@#\\\$(SITEPREFIX)/share/$app_name#g\\" < conf/httpd.conf > \\\$(SITEPREFIX)/share/$app_name/conf/httpd.conf
	cp conf/startup.pl \\\$(SITEPREFIX)/share/$app_name/conf
	cp -a templates \\\$(SITEPREFIX)/share/$app_name
ENDS
}
ENDM
}

sub write_startup_pl {
	my $self = shift;
	my $sess_class = $self->session_class;
	wf('conf/startup.pl', sprintf(<<ENDM
use strict;
use warnings FATAL => 'all';

BEGIN {
	push \@INC, \$ENV{%s} . "/blib/lib";
};

use $sess_class;
my \$sess_dir = $sess_class\->sessions_dir;
mkdir \$sess_dir if \$sess_dir;

1;
ENDM
		, $self->root_var_name));
	wf('>MANIFEST', "conf/startup.pl\n");
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
	wf('>MANIFEST', "$module_file\n") unless $no_manifest;
}

sub add_class { 
	my ($self, $new_class, $str) = @_;
	$self->write_pm_file($new_class, $str || "");
}

sub write_session_pm {
	my $self = shift;
	my $an = $self->app_name;
	my $sess_dir = "/tmp/$an\_sessions";
	$self->add_class($self->session_class, <<ENDM);
use base 'Apache::SWIT::Session';

sub sessions_dir { return '$sess_dir'; }
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
	$self->write_pm_file($self->connection_class, <<ENDM);
use base 'Class::Singleton', 'Class::Accessor';
use DBI;

__PACKAGE__->mk_accessors('db_handle');

sub _new_instance {
	my (\$class, \$handle) = \@_;
	die "No $db_var\_NAME given!" unless \$ENV{$db_var\_NAME};
	my \$dbh = \$handle || DBI->connect("dbi:Pg:dbname=" 
			. \$ENV{$db_var\_NAME}, undef, undef, {
			RaiseError => 1, AutoCommit => 1, })
		or die "Unable to connect to \$ENV{$db_var\_NAME} db";
	return \$class->new({ db_handle => \$dbh });
}
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
our \$test_db = Test::TempDatabase->create(dbname => '$an\_test_db',
                        schema => '$sc');
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
Include conf/my.conf
PerlSetEnv $db_var\_NAME $an\_test_db
ENDM
}

sub more_stuff_in_httpd_conf_in { return 'PerlModule @SessionClass@'; }

sub write_httpd_conf_in {
	my $self = shift;
	my $root_location = $self->root_location;
	my $more = $self->more_stuff_in_httpd_conf_in;
	mani_wf('conf/httpd.conf.in', sprintf(<<ENDM
PerlSetEnv %s \@ServerRoot\@
PerlRequire \@ServerRoot\@/conf/startup.pl

$more
<Location $root_location>
	PerlSetVar SWITRoot \@ServerRoot\@/
	PerlAccessHandler \@SessionClass\@\->access_handler
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
# Do not add anything to this file
# You can use t/apache_test.pl for custom stuff
use Apache::TestRunPerl;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

\$ENV{SWIT_HAS_APACHE} = 1;
push \@ARGV, '-top_dir', abs_path(dirname(\$0) . "/../");
Apache::TestRunPerl->new->run(\@ARGV);
ENDM
}

sub write_direct_test_pl {
	mani_wf('t/direct_test.pl', <<ENDM);
use strict;
use warnings FATAL => 'all';
use Test::Harness;
use T::TempDB;

runtests(\@ARGV);
ENDM
}

sub write_t_dual_001_load_t {
	my $self = shift;
	my $use_ok_class = $self->dual_use_ok_class;
	$self->add_test('t/dual/001_load.t', 2, <<ENDM);
use T::Test;

BEGIN { use_ok('$use_ok_class'); }

my \$t = T::Test->new;
\$t->ok_ht_index_r(make_url => 1, ht => { first => '' });
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

sub write_db_base_pm {
	my $self = shift;
	my $conn = $self->db_base_pm_connection;
	$self->write_pm_file($self->root_class . "::DB::Base", <<ENDS);
use base 'Class::DBI';
sub db_Main {
	return $conn->instance->db_handle;
}
ENDS
}

sub write_swit_app_pl {
	my $self = shift;
	my $self_class = ref($self);
	mani_wf('scripts/swit_app.pl', <<ENDS);
#!/usr/bin/perl -w
use strict;
use $self_class;
my \$f = shift(\@ARGV);
$self_class\->new->\$f(\@ARGV);
ENDS
	chmod 0755, 'scripts/swit_app.pl';
}

sub write_initial_files {
	my $self = shift;
	wf('>MANIFEST', "\n");

	$self->write_swit_yaml;
	$self->write_session_pm;
	$self->write_db_schema_file;
	$self->write_test_db_file;
	$self->write_db_connection_pm;
	$self->write_t_extra_conf_in;
	$self->write_httpd_conf_in;
	$self->write_t_dual_001_load_t;
	$self->write_direct_test_pl;
	$self->write_apache_test_run_pl;
	$self->write_apache_test_pl;
	$self->write_makefile_rules_yaml;
	$self->write_makefile_pl;
	$self->write_startup_pl;
	$self->write_db_base_pm;
	$self->write_010_db_t;
	$self->write_swit_app_pl;
	$self->add_ht_page('Index');
}

=head2 add_page(page)

Adds page and related files. Page should be the name of the module, 
e.g. 'Index'. See C<add_ht_page> for adding HTML::Tested enabled page.

=cut
sub add_page {
	my ($self, $page_class, $tmpl_str) = @_;
	$tmpl_str ||= '';
	my $tree = YAML::LoadFile('conf/swit.yaml') 
			or die "No conf/swit.yaml found";
	my $entry_point = lc($page_class);
	$entry_point =~ s/::/\//g;
	my $tt_file = "templates/$entry_point.tt";
	my $full_class = $tree->{root_class} . "::UI::$page_class";
	my $entry = {
		class => $full_class,
		template => $tt_file,
		location => $tree->{root_location} . "/$entry_point",
	};
	$tree->{pages}->{$entry_point} = $entry;
	$self->dump_yaml_conf($tree);

	mani_wf($tt_file, <<ENDM);
<html>
<body>
<form action="u" method="post">
$tmpl_str
</form>
</body>
</html>
ENDM
	$self->write_pm_file($full_class, <<ENDM);
use base qw(Apache::SWIT);

sub swit_render {
	my (\$class, \$req) = \@_;
	my \$res = {};
	return \$res;
}
ENDM
	return $entry;
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
	my $self = shift;
	my $p = $self->add_page(@_, '[% first %]');
	my $module_file = "lib/" . $p->{class} . ".pm";
	$module_file =~ s/::/\//g;
	my $loc = $p->{location};
	my $full_class = $p->{class};
	my $ht_root = $self->ht_root_class_name($p);
	wf_path($module_file, <<ENDM);
use strict;
use warnings FATAL => 'all';

package $full_class\::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_marked_value('first');

package $full_class;
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return $ht_root; }

sub ht_swit_render {
	my (\$class, \$r, \$root) = \@_;
	return \$root;
}

sub ht_swit_update {
	my (\$class, \$r, \$root) = \@_;
	return "$loc/r";
}

1;
ENDM
}

sub location_section {
	my ($self, $entry) = @_;
	return <<ENDS
<Location $entry->{location}>
	SetHandler perl-script
	PerlSetVar SWITTemplate \@ServerRoot\@/$entry->{template}
	PerlHandler $entry->{class}
</Location>
ENDS
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

sub strip_root {
	my ($self, $val, $root) = @_;
	$val =~ s/^$root//;
	return $val;
}

sub strip_roots {
	my ($self, $entry, %strips) = @_;
	my %res;
	while (my ($n, $v) = each %strips) {
		$res{$n} = $self->strip_root($entry->{$n}, $v);
	}
	return \%res;
}

sub session_class_for_httpd_conf {
	return $_[1]->{session_class};
}

sub regenerate_httpd_conf {
	my $self = shift;
	my $tree = $self->load_yaml_conf;
	my $ht_in = rf('conf/httpd.conf.in');
	my $sc = $self->session_class_for_httpd_conf($tree);
	$ht_in =~ s/\@SessionClass\@/$sc/g;

	wf('conf/httpd.conf', "$ht_in\n" . join("\n", map { 
		$self->location_section($_); 
	} values %{ $tree->{pages} }));
	my $c = rf('conf/httpd.conf');
	my $ap = abs_path('.');
	$c =~ s/\@ServerRoot\@/$ap/g;
	wf('t/conf/my.conf', $c);

	my $aliases = "";
	my $rl = $tree->{root_location};
	for my $p (values %{ $tree->{pages} }) {
		my $new_loc = $self->strip_root($p->{location}, "$rl/");
		$aliases .= "\"$new_loc\" => '" 
				. $self->alias_class($p->{class}) . "',\n";
	}

	my $sess_class = $self->session_class_for_httpd_conf($tree);
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
	$class->remove_file($p->{template});
	YAML::DumpFile('conf/swit.yaml', $tree);
}

sub get_makefile_rules {
	my $rules = YAML::LoadFile('conf/makefile_rules.yaml')
		or die "No makefile rules found";
	my $res = "";
	for my $r (@$rules) {
		$res .= $r->{target} . " :: ";
		$res .= join(' ', @{ $r->{dependencies} }) . "\n\t";
		$res .= join("\n\t", @{ $r->{actions} }) . "\n\n";
	}
	return $res;
}

1;
