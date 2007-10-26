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

sub makefile_class { return 'Apache::SWIT::Subsystem::Makefile'; }

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

sub write_950_install_t {
	my $self = shift;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	$self->add_test('t/950_install.t', 1, <<ENDT);
use Apache::SWIT::Maker;
use Apache::SWIT::Test::ModuleTester;
use Apache::SWIT::Test::Utils;
use File::Slurp;

my \$mt = Apache::SWIT::Test::ModuleTester->new({ root_class => '$rc' });
\$mt->run_make_install;

chdir \$mt->root_dir;

\$mt->make_swit_project(root_class => 'MU');
\$mt->install_subsystem('TheSub');

my \$res = join('', `perl Makefile.PL && make test 2>&1`);
unlike(\$res, qr/Error/) or do {
	diag(read_file('t/logs/error_log'));
	ASTU_Wait(\$mt->root_dir);
};

chdir '/';
ENDT
}

# InstallationContent inherits it
sub write_maker_pm {
	my $self = shift;
	$self->write_pm_file(Apache::SWIT::Maker::Config->instance->root_class . "::Maker", <<ENDM);
use base 'Apache::SWIT::Subsystem::Maker';
ENDM
}

sub write_initial_files {
	my $self = shift;
	$self->SUPER::write_initial_files(@_);
	$self->write_950_install_t;
	$self->write_maker_pm;
}

sub add_class {
	my ($self, $new_class, $str) = @_;
	$self->SUPER::add_class($new_class, $str);
	Apache::SWIT::Maker::Config->instance->add_startup_class($new_class);
}

sub write_swit_yaml {
	my $gens = Apache::SWIT::Maker::Config->instance->generators;
	push @$gens, 'Apache::SWIT::Subsystem::Generator';
	shift()->SUPER::write_swit_yaml;
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
	my $tests = $self->this_subsystem_original_tree->{dumped_tests};
	while (my ($n, $t) = each %$tests) {
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

1;
