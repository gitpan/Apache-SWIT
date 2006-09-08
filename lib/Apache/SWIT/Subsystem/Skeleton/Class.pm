use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Class;
use base 'Apache::SWIT::Maker::Skeleton::Class';
use Apache::SWIT::Subsystem::Skeleton::PageClasses;

sub write_output {
	my $self = shift;
	$self->SUPER::write_output(@_);
	Apache::SWIT::Subsystem::Skeleton::PageClasses->add($self->class_v);
}

1;
