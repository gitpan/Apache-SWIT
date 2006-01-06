use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Maker;
use base 'Apache::SWIT::Maker';
use Data::Dumper;

sub makefile_install_string {
	my $rc = shift()->root_class;
	return <<ENDM;
sub install {
	my \$res = shift()->SUPER::install(\@_);
	\$res =~ s/pure_(\\w+)_install ::/pure_\$1\_install ::\n\tperl -I lib -M$rc\::Maker -e '$rc\::Maker->new->write_installation_content_pm'/g;
	return \$res;
}
ENDM
}

sub make_this_subsystem_dumps {
	my $self = shift;
	my $rc = $self->root_class;
	my $tree = $self->load_yaml_conf;
	my %pages;
	my $rl = $tree->{root_location} . "/";
	while (my ($n, $v) = each %{ $tree->{pages} }) {
		$pages{$n} = $self->strip_roots($v, location => $rl, 
						template => 'templates/',
						class => "$rc\::");
		$pages{$n}->{file} = Apache::SWIT::Maker::rf($v->{template});
	}
	open(my $fh, 'MANIFEST');
	my @dual_tests = map { s/t\/dual\///; $_ } 
				grep { /t\/dual\/.+\.t$/ } <$fh>;
	my %tests = map { 
		($_, Apache::SWIT::Maker::rf("t/dual/$_")) 
	} @dual_tests;
	close $fh;
	return (tests => \%tests, pages => \%pages);
}

sub write_installation_content_pm {
	my $self = shift;
	my %dumps = $self->make_this_subsystem_dumps;
	my $res = "";
	while (my ($n, $v) = each %dumps) {
		my $v_str = Dumper($v);
		$res .= <<ENDS;
sub this_subsystem_$n {
	my $v_str;
	return \$VAR1;
}
ENDS
	}

	$self->with_lib_dir('blib/lib', sub {
		$self->write_pm_file(
			$self->root_class . "::InstallationContent", $res, 1);
	});
}

sub write_t_module {
	my $self = shift;
	my $conn_class = $self->connection_class;
	my $rc = $self->root_class;
	$self->write_pm_file("T::$rc", <<ENDM);
use base '$rc';
__PACKAGE__->inherit_classes("$conn_class");
ENDM
}

sub t_dbi_base_class { return "T::" . shift()->SUPER::t_dbi_base_class; }
sub use_ok_in_010_db_t { return 'T::' . shift()->root_class; }

sub rewrite_root_module {
	my $self = shift;
	my $rc = $self->root_class;
	$self->write_pm_file($rc, <<ENDM);
use base '$rc\::PageClasses';

our \$VERSION = 0.01;

sub classes_for_inheritance { 
	# Add classes to inherit from relative to package
	return (__PACKAGE__, 'DB::Base', 
			shift()->SUPER::classes_for_inheritance);
}
ENDM
}

sub write_950_install_t {
	my $self = shift;
	my $rc = $self->root_class;
	$self->add_test('t/950_install.t', 1, <<ENDT);
use Apache::SWIT::Maker;
use Apache::SWIT::Test::ModuleTester;

my \$mt = Apache::SWIT::Test::ModuleTester->new({ root_class => '$rc' });
\$mt->run_make_install;

chdir \$mt->root_dir;

\$mt->make_swit_project(root_class => 'MU');
\$mt->install_subsystem('TheSub');

my \$res = join('', `perl Makefile.PL && make test 2>&1`);
unlike(\$res, qr/Error/);

chdir '/';
ENDT
}

sub more_stuff_in_httpd_conf_in { 
	return 'PerlModule T::' . shift()->root_class; 
}

sub write_maker_pm {
	my $self = shift;
	$self->write_pm_file($self->root_class . "::Maker", <<ENDM);
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

sub connection_class { return "T::" . shift()->SUPER::connection_class }

sub add_class {
	my ($self, $new_class, $str) = @_;
	$self->SUPER::add_class($new_class, $str);
	my $tree = $self->load_yaml_conf;
	$tree->{classes_for_inheritance} = [] 
		unless $tree->{classes_for_inheritance};
	push @{ $tree->{classes_for_inheritance} }, $new_class;
	$self->dump_yaml_conf($tree);
}

sub regenerate_httpd_conf {
	my $self = shift;
	my $rc = $self->root_class;
	my $tree = $self->SUPER::regenerate_httpd_conf;
	my $page_classes = join("\n", map {
		s/^$rc\:://;
		$_;
	} @{ $tree->{classes_for_inheritance} }) . "\n";
	my $funcs = "";
	for my $p (values %{ $tree->{pages} }) {
		my $base = $p->{class};
		my $root = "$base\::Root";

		$base =~ s/^$rc\:://;
		$page_classes .= "$base\n";

		my $f_stem = lc($base);
		$f_stem =~ s/::/_/g;

		my $t_basename = $p->{template};
		$t_basename =~ s/templates\///;

		$funcs .= <<ENDF;
__PACKAGE__->mk_classdata('$f_stem\_root_class', '$root');
__PACKAGE__->mk_classdata('$f_stem\_template', '$t_basename');\n
ENDF
	}
	$self->with_lib_dir("blib/lib", sub {
		$self->write_pm_file("$rc\::PageClasses", <<ENDM, 1);
use base 'Apache::SWIT::Subsystem::Base';

sub classes_for_inheritance { return qw($page_classes); }

$funcs
ENDM
	});
}

sub location_section {
	my ($self, $entry) = @_;
	my $res = $self->SUPER::location_section($entry);
	my $ec = $entry->{class};
	$res =~ s/$ec/T::$ec/;
	return $res;
}

sub base_func_name {
	my ($self, $entry) = @_;
	my $base = $entry->{class};
	my $root = $self->root_class;
	$base =~ s/$root\:://;
	$base =~ s/::/_/g;
	return lc($base)
}

sub ht_root_class_name {
	my ($self, $entry) = @_;
	my $func = $self->base_func_name($entry) . "_root_class";
	return "shift()->main_subsystem_class->$func";
}

sub alias_class { return "T::" . $_[1]; }

sub dual_use_ok_class { return "T::" . shift()->root_class; }

sub db_base_pm_connection {
	return 'shift()->main_subsystem_class->connection_class';
}

sub session_class_for_httpd_conf {
	return "T::" . $_[1]->{session_class};
}

sub install_subsystem {
	my ($self, $module) = @_;
	my $lcm = lc($module);
	my $rc = $self->root_class;
	my $full_name =  $rc . '::' . $module;

	my $tree = $self->load_yaml_conf;
	my $pages = $self->this_subsystem_pages;
	while (my ($n, $v) = each %$pages) {
		my $entry = {
			location => ($tree->{root_location} 
					. "/$lcm/" . $v->{location}),
			template => "templates/$lcm/" . $v->{template},
			class => "$rc\::$module\::" . $v->{class},
		};
		$tree->{pages}->{"$lcm/$n"} = $entry;
		Apache::SWIT::Maker::mani_wf($entry->{template}, $v->{file});
	}
	$self->dump_yaml_conf($tree);

	my $sn = $self->this_subsystem_name;
	my $conn_name = $self->SUPER::connection_class;
	$self->write_pm_file($full_name, <<ENDM);
use base '$sn';

sub templates_dir { return 'templates/$lcm'; }

__PACKAGE__->inherit_classes('$conn_name');
ENDM
	Apache::SWIT::Maker::wf('>conf/httpd.conf.in', 
			"PerlModule $full_name\n");

	my $tests = $self->this_subsystem_tests;
	while (my ($n, $t) = each %$tests) {
		$t =~ s/T::$sn/$full_name/g;
		$t =~ s/ht_([^\(\)]+_[ru])/ht_$lcm\_$1/g;
		Apache::SWIT::Maker::mani_wf("t/dual/$lcm/$n", $t);
	}
}

sub this_subsystem_name {
	my $class = ref(shift());
	$class =~ s/::Maker$//;
	return $class;
}

sub get_installation_content {
	my ($self, $func) = @_;
	my $ic = $self->this_subsystem_name . "::InstallationContent";
	eval "use $ic";
	die "Unable to use $ic: $@" if $@;
	return $ic->$func;
}

sub this_subsystem_pages { 
	shift()->get_installation_content('this_subsystem_pages');
}

sub this_subsystem_tests {
	shift()->get_installation_content('this_subsystem_tests');
}

1;
