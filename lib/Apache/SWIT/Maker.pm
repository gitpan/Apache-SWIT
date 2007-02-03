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
use File::Copy;
use Cwd qw(abs_path getcwd);
use Apache::SWIT::Maker::GeneratorsQueue;
use Apache::SWIT::Maker::FileWriterData;
use Apache::SWIT::Maker::Conversions;
use Apache::SWIT::Maker::Config;
use Apache::SWIT::Maker::Makefile;
use File::Slurp;
use Apache::SWIT::Maker::Manifest;
use ExtUtils::Manifest qw(maniread manicopy);
use File::Temp qw(tempdir);

__PACKAGE__->mk_accessors(qw(lib_dir file_writer));

my @_initial_skels = qw(apache_test apache_test_run dual_001_load startup);

sub _load_skeleton {
	my ($class, $skel_class, $func) = @_;
	my $s = 'Apache::SWIT::Maker::Skeleton::' . $skel_class;
	conv_eval_use($s);

	no strict 'refs';
	*{ __PACKAGE__ . "::$func" } = sub { return $s; }
		unless __PACKAGE__->can($func);
}

__PACKAGE__->_load_skeleton(conv_table_to_class($_), $_) for @_initial_skels;

my %_page_skels = (qw(skel_page Page skel_template Template
		skel_ht_page HT::Page skel_ht_template HT::Template
		skel_db_class DB::Class scaffold_dual_test Scaffold::DualTest)
		, map { ("scaffold_".lc($_), "Scaffold::$_"
			, "scaffold_".lc($_)."_template"
			, "Scaffold::$_"."Template") } qw(List Form Info));

while (my ($n, $v) = each %_page_skels) {
	__PACKAGE__->_load_skeleton($v, $n);
}

sub makefile_class { return 'Apache::SWIT::Maker::Makefile'; }

sub new {
	my $self = shift->SUPER::new(@_);
	$self->lib_dir("lib") unless $self->lib_dir;
	$self->{file_writer} ||= Apache::SWIT::Maker::FileWriterData->new;
	return $self;
}

sub schema_class {
	return Apache::SWIT::Maker::Config->instance->root_class
		. '::DB::Schema';
}

sub write_swit_yaml {
	swmani_write_file('conf/swit.yaml', "");
	Apache::SWIT::Maker::Config->instance->save;
}

sub write_makefile_pl {
	my $self = shift;
	my $args = Apache::SWIT::Maker::Makefile::Args();
	my $mc = $self->makefile_class;
	write_file('Makefile.PL', <<ENDM);
use strict;
use warnings FATAL => 'all';
use $mc;

$mc\->new->write_makefile$args;
ENDM
}

sub write_pm_file {
	my ($self, $module_class, $str, $no_manifest) = @_;
	my $module_file = $self->lib_dir . "/$module_class.pm";
	$module_file =~ s/::/\//g;
	mkpath_write_file($module_file, <<ENDM);
use strict;
use warnings FATAL => 'all';

package $module_class;
$str

1;
ENDM
	append_file('MANIFEST', "\n$module_file") unless $no_manifest;
}

sub add_class { 
	my ($self, $new_class, $str) = @_;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	$new_class = $rc . "::$new_class" if ($new_class !~ /^$rc\::/);
	$self->file_writer->write_lib_pm({ content => $str }
			, { new_root => $new_class });
}

sub write_session_pm {
	my $self = shift;
	my $an = Apache::SWIT::Maker::Config->instance->app_name;
	$self->add_class(Apache::SWIT::Maker::Config->instance
			->session_class, <<ENDM);
use base 'Apache::SWIT::Session';

sub cookie_name { return '$an'; }

ENDM
}

sub db_env_var {
	my $db_var = Apache::SWIT::Maker::Config->instance->root_env_var;
	$db_var =~ s/ROOT$/DB/;
	return $db_var;
}

sub write_db_connection_pm {
}

sub write_db_schema_file {
	my $self = shift;
	my $an = Apache::SWIT::Maker::Config->instance->app_name;
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
	my $an = Apache::SWIT::Maker::Config->instance->app_name;
	my $db_var = $self->db_env_var;
	$self->with_lib_dir('t', sub {
		$self->write_pm_file('T::TempDB', <<ENDM);
use Test::TempDatabase;
use $sc;
use Apache::SWIT::DB::Connection;

\$ENV{APACHE_SWIT_DB_NAME} = '$an\_test_db';
our \$test_db = Test::TempDatabase->create(
			dbname => '$an\_test_db', schema => '$sc'
			, dbi_args => Apache::SWIT::DB::Connection->DBIArgs);
Apache::SWIT::DB::Connection->instance(\$test_db->handle);
END { \$test_db->destroy; }
ENDM
	});
}

sub write_t_extra_conf_in {
	my $self = shift;
	my $an = Apache::SWIT::Maker::Config->instance->app_name;
	my $db_var = $self->db_env_var;
	swmani_write_file('t/conf/extra.conf.in', <<ENDM);
PerlSetEnv APACHE_SWIT_DB_NAME $an\_test_db
Include ../blib/conf/httpd.conf
ENDM
}

sub more_stuff_in_httpd_conf_in {
	my $self = shift;
	my $rl = Apache::SWIT::Maker::Config->instance->root_location;
	return <<ENDS
RewriteEngine on
RewriteRule ^/\$ $rl/index/r [R]
PerlModule \@SessionClass\@;
ENDS
}

sub write_httpd_conf_in {
	my $self = shift;
	my $root_location = Apache::SWIT::Maker::Config->instance
				->root_location;
	my $more = $self->more_stuff_in_httpd_conf_in;
	my $app_name = Apache::SWIT::Maker::Config->instance->app_name;
	my $seed = $$ . int(rand(65530)) . time;
	swmani_write_file('conf/httpd.conf.in', sprintf(<<ENDM
PerlSetEnv %s \@ServerRoot\@
<Perl>
	use lib '\@ServerRoot\@/lib';
</Perl>
PerlRequire \@ServerRoot\@/conf/startup.pl

$more
<Location $root_location>
	PerlAccessHandler \@SessionClass\@\->access_handler
	PerlSetVar SWITSessionsDir /tmp/$app_name-sessions
</Location>
Alias $root_location/www \@ServerRoot\@/public_html 
Alias /html-tested-javascript /usr/local/share/libhtml-tested-javascript-perl
ENDM
		, Apache::SWIT::Maker::Config->instance->root_env_var));

}

sub use_ok_in_010_db_t {
	return Apache::SWIT::Maker::Config->instance->root_class;
}

sub add_test {
	my ($self, $file, $number, $content) = @_;
	unless ($number) {
		$number = 1;
		$content = "BEGIN { use_ok('"
			. Apache::SWIT::Maker::Config->instance->root_class
			."'); }";
	}
	swmani_write_file($file, <<ENDT);
use strict;
use warnings FATAL => 'all';

use Test::More tests => $number;

$content
ENDT
}

sub write_010_db_t {
	my $self = shift;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	my $more_uses = $self->use_ok_in_010_db_t;
	$self->add_test('t/010_db.t', 2, <<ENDM);
use T::TempDB;

BEGIN { use_ok('$more_uses');
}

package T::DBI;
use base 'Apache::SWIT::DB::Base';
__PACKAGE__->table('test_table');
__PACKAGE__->columns(Essential => qw/a b/);

package main;
Apache::SWIT::DB::Connection->instance->db_handle->do(
		"create table test_table (a integer, b text)");
is_deeply([ T::DBI->retrieve_all ], []);

ENDM
}

sub write_swit_app_pl {
	my $self = shift;
	$self->file_writer->write_scripts_swit_app_pl({
				class => ref($self) });
	chmod 0755, 'scripts/swit_app.pl';
}

sub install {
	my ($self, $inst_dir) = @_;
	$self->makefile_class->do_install("blib", $inst_dir);
}

sub write_initial_files {
	my $self = shift;
	$self->$_->new->write_output for @_initial_skels;

	$self->write_swit_yaml;
	$self->write_session_pm;
	$self->write_db_schema_file;
	$self->write_test_db_file;
	$self->write_db_connection_pm;
	$self->write_t_extra_conf_in;
	$self->write_httpd_conf_in;
	swmani_write_file("public_html/main.css", "# Sample CSS file\n");
	$self->file_writer->write_t_direct_test_pl;
	$self->file_writer->write_conf_makefile_rules_yaml;
	$self->write_makefile_pl;
	$self->write_010_db_t;
	$self->write_swit_app_pl;
	$self->add_ht_page('Index');
}

sub _make_page {
	my ($self, $page_class, $args, @funcs) = @_;
	my $i = Apache::SWIT::Maker::Config->instance;
	my $e = $i->create_new_page($page_class);
	for my $f (@funcs) {
		my $p = $self->$f->new($args);
		$p->config_entry($e);
		$p->write_output;
	}
	$i->save;
	return $e;
}

=head2 add_page(page)

Adds page and related files. Page should be the name of the module, 
e.g. 'Index'. See C<add_ht_page> for adding HTML::Tested enabled page.

=cut
sub add_page {
	my ($self, $pc) = @_;
	return $self->_make_page($pc, {}, qw(skel_template skel_page));
}

=head2 add_ht_page(page)

Adds HTML::Tested enabled page and related files. 
Page should be the name of the module, e.g. 'Index'.

=cut
sub add_ht_page {
	my ($self, $pc) = @_;
	return $self->_make_page($pc, {}, qw(skel_ht_template skel_ht_page));
}

sub alias_class { return $_[1]; }

sub session_class_for_httpd_conf {
	return $_[1]->{session_class};
}

sub httpd_location_section {
	my ($self, $gq, $loc, $entry) = @_;
	my $res = $gq->run('location_section_prolog', $loc, $entry);
	my $l = Apache::SWIT::Maker::Config->instance->root_location ."/$loc";
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

sub regenerate_seal_key {
	my $seed = $$ . int(rand(65530)) . time;
	mkpath_write_file('blib/conf/seal.key', $seed);
}

sub regenerate_httpd_conf {
	my $self = shift;
	my $gq = Apache::SWIT::Maker::GeneratorsQueue->new;
	my $tree = Apache::SWIT::Maker::Config->instance;
	my $ht_in = $gq->run('httpd_conf_start');

	my $aliases = "";
	while (my ($n, $v) = each %{ $tree->{pages} }) {
		$ht_in .= $self->httpd_location_section($gq, $n, $v) . "\n";
		$aliases .= "\"$n\" => '"
				. $self->alias_class($v->{class}) . "',\n";
	}

	mkpath_write_file('blib/conf/httpd.conf', $ht_in);
	$self->makefile_class->deploy_httpd_conf("blib", "blib");
	$self->file_writer->write_t_t_test_pm({
		session_class => $tree->{session_class}
		, root_location => $tree->{root_location}
		, root_env_var => $tree->root_env_var,
		, aliases => $aliases, httpd_session_class =>
			$self->session_class_for_httpd_conf($tree) });
	return $tree;
}

sub remove_file {
	my ($self, $file) = @_;
	swmani_filter_out($file);
	unlink($file);
}

=head2 remove_page(page)

Removes page and related files. Page is relative to the root location

=cut
sub remove_page {
	my ($class, $page) = @_;
	my $tree = Apache::SWIT::Maker::Config->instance;
	my $ep = lc($page);
	$ep =~ s/::/\//g;
	my $p = delete $tree->{pages}->{$ep} or die "Unable to find $page";
	my $module_file = "lib/" . $p->{class} . ".pm";
	$module_file =~ s/::/\//g;
	$class->remove_file($module_file);
	$class->remove_file($p->{entry_points}->{r}->{template});
	$tree->save;
}

sub add_db_class {
	my ($self, $table) = @_;
	$self->skel_db_class->new({ table => $table })->write_output;
}

sub _extract_columns {
	my ($self, $c) = @_;
	push @INC, "t", "lib";
	conv_eval_use('T::TempDB');
	conv_eval_use($c);
	my %pc = map { ($_, 1) } $c->primary_columns;
	return grep { !$pc{$_} } $c->columns;
}

sub scaffold {
	my ($self, $table) = @_;
	$self->add_db_class($table);
	my $ct = conv_table_to_class($table);
	my $db_class = Apache::SWIT::Maker::Config->instance->root_class
				. "::DB::$ct";

	my @cols = $self->_extract_columns($db_class);
	my $args = { columns => [ @cols ], table => $table };
	$self->scaffold_dual_test->new($args)->write_output;

	$self->_make_page("$ct\::$_", $args, "scaffold_".lc($_)
		, "scaffold_".lc($_)."_template") for qw(List Info Form);
}

sub run_server {
	my $dn = abs_path(dirname($0));
	$ENV{__APACHE_SWIT_RUN_SERVER__} = 1;
	system("make test_apache");
}

sub override {
	my ($self, $page) = @_;
	my $c = Apache::SWIT::Maker::Config->instance;
	my $p = $c->find_page($page) or die "Unable to find $page page";
	my $rc = $c->root_class;
	my $cc = $p->class;
	$cc =~ /^$rc\::(\w+)::UI::(\S+)$/
		or die "Unable to match " . Dumper($p);
	$p->class("$rc\::UI::$1\::$2");
	$p->do_not_use(undef);
	$self->add_class($p->class, "use base '$cc';");
	$c->save;
}

sub mv {
	my ($self, $from, $to) = @_;
	swmani_replace_file($from, $to);
	swmani_replace_in_files($from, $to);
	my ($cf, $ct) = (conv_file_to_class($from), conv_file_to_class($to));
	swmani_replace_in_files(-f $to ? sub {
		s/$cf\::Root/$ct\::Root/g;
		s/$cf([^:\w])/$ct$1/g;
	} : ($cf, $ct));

	my ($ef, $et) = map { conv_class_to_entry_point($_) } ($cf, $ct);
	my $cstr = read_file('conf/swit.yaml');
	($cstr =~ s#$ef(.*):#$et$1:#g) and write_file('conf/swit.yaml', $cstr);

	# change test functions
	my ($tf_f, $tf_t) = ($ef, $et);
	s#\/#_#g for ($tf_f, $tf_t);
	swmani_replace_in_files("ht_$tf_f", "ht_$tf_t");

	my $tt_ef = "templates/$ef";
	if (-f $to) {
		$tt_ef .= ".tt";
		$et .= ".tt";
	}
	$self->mv($tt_ef, "templates/$et") if ($cstr =~ m#$tt_ef#);
}

sub available_commands { return (
add_class => [ '<class> - adds new class.', 1 ]
, add_db_class => [ '<class> - adds new database class.', 1 ]
, add_ht_page => [ '<class> - adds new HTML::Tested based page.', 1 ]
, add_page => [ '<class> - adds new page.', 1 ]
, add_test => [ '<file> - adds new test file.' ]
, install => [ '<dir> - installs into dir.' ]
, mv => [ '<from> <to> - moves file or directory updating all things which
		reference it.', 1 ]
, override => [ '<class> - overrides page class by inheriting from it.' ]
, regenerate_httpd_conf => [ '- regenerates httpd.conf.' ]
, regenerate_seal_key => [ '- regenerates new seal key.' ]
, run_server => [ '- runs Apache on APACHE_TEST_PORT.' ]
, scaffold => [ '<table_name> - generates classes and templates supporting
		<table_name> CRUD operation.', 1 ]
); }

sub swit_app_cmd_params {
	my ($self, $cmd) = @_;
	my %cmds = $self->available_commands;
	return $cmds{$cmd} if ($cmd && $cmds{$cmd});
	my $res = "Usage: $0 <cmd> <args> where available commands are:\n";
	for my $n (sort keys %cmds) {
		my $v = $cmds{$n};
		$res .= "$n $v->[0]\n";
	}
	print $res;
	return undef;
}

sub silent_system {
	my ($self, $cmd) = @_;
	system("$cmd 2>&1 1>/dev/null") and die "Unable to do $cmd";
}

sub do_swit_app_cmd {
	my ($self, $cmd, @args) = @_;
	my $p = $self->swit_app_cmd_params($cmd) or return;
	my ($mf_before);
	local $ExtUtils::Manifest::Quiet = 1;
	my $bf_name = join("_", $cmd, @args);
	$bf_name =~ s/\W/_/g;
	my $cwd = getcwd();
	my $backup_dir = "$cwd/../$bf_name";
	if ($p->[1]) {
		$mf_before = maniread();
		manicopy($mf_before, $backup_dir);
		$self->silent_system("make realclean") if -f 'Makefile';
	}
	eval { $self->$cmd(@args); };
	my $err = $@;
	if ($err && $p->[1]) {
		chdir $backup_dir;
		manicopy($mf_before, $cwd);
		chdir $cwd;
	} elsif ($p->[1]) {
		mkpath("backups");
		my $mf = maniread();
		$mf->{$_} = 1 for keys %$mf_before;
		# diff returns 1 for some reason
		system("diff -uN $backup_dir/$_ $_ >> backups/$bf_name.patch")
				for (sort keys %$mf);
		$self->silent_system("perl Makefile.PL");
	}
	rmtree($backup_dir);
	die "Rolled back. Original exception is $err" if $err;
}

1;
