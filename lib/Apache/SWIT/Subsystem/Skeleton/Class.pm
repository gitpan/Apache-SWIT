use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Class;
use base 'Apache::SWIT::Maker::Skeleton::Class';

sub write_output {
	my $self = shift;
	$self->SUPER::write_output(@_);
	Apache::SWIT::Maker::Config->instance->add_startup_class(
			$self->class_v);
}

1;
