use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Base;
use base 'Class::Data::Inheritable';
use Apache::SWIT::Maker::Conversions;

__PACKAGE__->mk_classdata('templates_dir', 'templates/');

sub inherit_from_class {
	my ($class, $root, $basename) = @_;
	my $package = "$class\::$basename";
	my $rb = conv_eval_use("$root\::$basename");
	no strict 'refs';
	push @{ *{ "$package\::ISA" } }, $rb unless @{ *{ "$package\::ISA" } };
	return $rb;
}

sub inherit_classes {
	my ($class) = @_;
	my ($root_class, @others) = $class->classes_for_inheritance;
	my @packages = map { 
		$class->inherit_from_class($root_class, $_)
	} @others;
	$_->swit_startup 
		for grep { $_->can('swit_startup') } @packages;
}

1;
