use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Maker;
use base 'Apache::SWIT::Maker';
use Data::Dumper;
use Apache::SWIT::Maker::GeneratorsQueue;
use Apache::SWIT::Maker::Manifest;
use Apache::SWIT::Subsystem::Makefile;
use File::Slurp;
use Apache::SWIT::Maker::Conversions;
use Apache::SWIT::Subsystem::Skeleton::Class;
use Apache::SWIT::Subsystem::Skeleton::PageClasses;

sub makefile_class { return 'Apache::SWIT::Subsystem::Makefile'; }

my %_skel_overrides = qw(skel_db_class DB::Class dual_001_load Dual001Load
		scaffold_dual_test Scaffold::DualTest
		scaffold_form Scaffold::Form
		scaffold_list Scaffold::List
		scaffold_info Scaffold::Info);

while (my ($n, $v) = each %_skel_overrides) {
	my $sc = conv_eval_use("Apache::SWIT::Subsystem::Skeleton::" . $v);
	no strict 'refs';
	*{ __PACKAGE__ . "::" . $n } = sub { return $sc; };
}

for (qw(DB::Class)) {
	no strict 'refs';
	unshift @{ "Apache::SWIT::Subsystem::Skeleton::$_\::ISA" }
			, 'Apache::SWIT::Subsystem::Skeleton::Class';
}

sub make_this_subsystem_dumps {
	my $self = shift;
	my $gq = Apache::SWIT::Maker::GeneratorsQueue->new;
	my $orig_tree = Apache::SWIT::Maker::Config->instance;
	undef $Apache::SWIT::Maker::Config::_instance;
	while (my ($n, $v) = each %{ $orig_tree->{pages} }) {
		$orig_tree->{pages}->{$n} = $gq->run('dump_page_entry', $v);
	}
	my @dual_tests = map { s#t/dual/##; $_ } swmani_dual_tests();
	my %tests = map {
		my $t = read_file("t/dual/$_");
		($_, $t)
	} @dual_tests;
	$orig_tree->{dumped_tests} = \%tests;
	return (original_tree => $orig_tree);
}

sub write_installation_content_pm {
	my $self = shift;
	my %dumps = $self->make_this_subsystem_dumps;
	$self->file_writer->write_blib_lib_installationcontent_pm({
		dumps => [ map {
			{ name => $_, 'dump' => Dumper($dumps{$_}) }
	} keys %dumps ] })
}

sub write_t_module {
	my $self = shift;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	my $rvn = Apache::SWIT::Maker::Config->instance->root_env_var;
	$self->write_pm_file("T::$rc", <<ENDM);
use base '$rc';
use Apache::SWIT::Test;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

\$ENV{SWIT_BLIB_DIR} = abs_path(dirname(\$0) . "/../blib");
Apache::SWIT::Test->do_startup('$rvn') unless \$ENV{$rvn};
__PACKAGE__->inherit_classes;
ENDM
}

sub use_ok_in_010_db_t { return 'T::' . Apache::SWIT::Maker::Config->instance->root_class; }

sub rewrite_root_module {
	my $self = shift;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	$self->write_pm_file($rc, <<ENDM);
use base '$rc\::PageClasses';

our \$VERSION = 0.01;

sub classes_for_inheritance { 
	# Add classes to inherit from relative to package
	return (__PACKAGE__, shift()->SUPER::classes_for_inheritance);
}
ENDM
}

sub write_950_install_t {
	my $self = shift;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	$self->add_test('t/950_install.t', 1, <<ENDT);
use Apache::SWIT::Maker;
use Apache::SWIT::Test::ModuleTester;
use Apache::SWIT::Test::Utils;

my \$mt = Apache::SWIT::Test::ModuleTester->new({ root_class => '$rc' });
\$mt->run_make_install;

chdir \$mt->root_dir;

\$mt->make_swit_project(root_class => 'MU');
\$mt->install_subsystem('TheSub');

my \$res = join('', `perl Makefile.PL && make test 2>&1`);
unlike(\$res, qr/Error/) or ASTU_Wait(\$mt->root_dir);

chdir '/';
ENDT
}

sub more_stuff_in_httpd_conf_in { 
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	return 'PerlModule T::' . "$rc\n"; 
}

sub write_maker_pm {
	my $self = shift;
	$self->write_pm_file(Apache::SWIT::Maker::Config->instance->root_class . "::Maker", <<ENDM);
use base 'Apache::SWIT::Subsystem::Maker';
ENDM
}

sub write_db_connection_pm {
	my $self = shift;
	$self->rewrite_root_module;
	$self->write_950_install_t;
	$self->write_maker_pm;
	$self->with_lib_dir("t", sub {
		$self->SUPER::write_db_connection_pm;
		$self->write_t_module;
		$self->remove_file('t/001_load.t');
	});
}

sub add_class {
	my ($self, $new_class, $str) = @_;
	$self->SUPER::add_class($new_class, $str);
	Apache::SWIT::Subsystem::Skeleton::PageClasses->add($new_class);
}

sub regenerate_httpd_conf {
	my $self = shift;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	$self->SUPER::regenerate_httpd_conf;
	Apache::SWIT::Subsystem::Skeleton::PageClasses->new->write_output;
}

sub write_swit_yaml {
	my $gens = Apache::SWIT::Maker::Config->instance->generators;
	push @$gens, 'Apache::SWIT::Subsystem::Generator';
	shift()->SUPER::write_swit_yaml;
}

sub alias_class { return "T::" . $_[1]; }

sub session_class_for_httpd_conf {
	return "T::" . $_[1]->{session_class};
}

sub install_subsystem {
	my ($self, $module) = @_;
	my $lcm = lc($module);
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	my $full_name =  $rc . '::' . $module;

	my $orig_tree = $self->this_subsystem_original_tree;
	my $gq = Apache::SWIT::Maker::GeneratorsQueue->new({
			generator_classes => $orig_tree->{generators} });
	my $tree = Apache::SWIT::Maker::Config->instance;
	while (my ($n, $v) = each %{ $orig_tree->{pages} }) {
		$tree->{pages}->{"$lcm/$n"} = 
			$gq->run('install_page_entry', $v, $module);
	}
	$tree->save;

	my $sn = $self->this_subsystem_name;
	$self->write_pm_file($full_name, <<ENDM);
use base '$sn';

sub templates_dir { return 'templates/$lcm'; }

__PACKAGE__->inherit_classes;
ENDM
	append_file('conf/httpd.conf.in', "PerlModule $full_name\n");

	my $tests = $self->this_subsystem_original_tree->{dumped_tests};
	while (my ($n, $t) = each %$tests) {
		$t =~ s/T::$sn/$full_name/g;
		$t =~ s/ht_([^\(\)]+_[ru])/ht_$lcm\_$1/g;
		swmani_write_file("t/dual/$lcm/$n", $t);
	}
}

sub this_subsystem_name {
	my $class = ref(shift());
	$class =~ s/::Maker$//;
	return $class;
}

sub get_installation_content {
	my ($self, $func) = @_;
	return conv_eval_use($self->this_subsystem_name
			. "::InstallationContent")->$func;
}

sub this_subsystem_original_tree { 
	return shift()->get_installation_content(
				'this_subsystem_original_tree');
}

sub use_to_extract {
	system("make > /dev/null");
	use lib 'blib/lib';
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	conv_eval_use('T::' . $rc);
	return 'T::' . $_[1];
}

1;
