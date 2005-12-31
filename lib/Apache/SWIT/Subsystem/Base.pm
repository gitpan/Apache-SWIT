use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Base;
use base 'Class::Data::Inheritable';

__PACKAGE__->mk_classdata('connection_class');
__PACKAGE__->mk_classdata('templates_dir', 'templates/');

sub inherit_from_class {
	my ($class, $root, $basename) = @_;
	my $base_class = "$root\::$basename";
	eval "use $base_class";
	die "Unable to use $base_class: $@" if $@;

	my $package = "$class\::$basename";
	no strict 'refs';
	push @{ *{ "$package\::ISA" } }, $base_class
		unless @{ *{ "$package\::ISA" } };
	push @{ *{ "$package\::ISA" } }, "Class::Data::Inheritable"
		unless $package->can('mk_classdata');

	$package->mk_classdata('main_subsystem_class');
	$package->main_subsystem_class($class);

	my $data_var = lc($basename) . "_class";
	$data_var =~ s/::/_/g;
	$class->mk_classdata($data_var);
	$class->$data_var($package);
	return $package;
}

sub inherit_classes {
	my ($class, $conn_class) = @_;
	eval "use $conn_class";
	die "Unable to use $conn_class: $@" if $@;

	my ($root_class, @others) = $class->classes_for_inheritance;
	my @packages = map { 
		$class->inherit_from_class($root_class, $_)
	} @others;
	$class->connection_class($conn_class);
	$_->on_inheritance_end 
		for grep { $_->can('on_inheritance_end') } @packages;
}

1;
