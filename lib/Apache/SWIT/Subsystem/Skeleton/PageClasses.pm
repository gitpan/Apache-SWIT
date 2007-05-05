use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::PageClasses;
use base 'Apache::SWIT::Maker::Skeleton';

sub add {
	my $tree = Apache::SWIT::Maker::Config->instance;
	push @{ $tree->{startup_classes} }, $_[1];
	$tree->save;
}

sub output_file {
	my $res = 'blib/lib/' . shift()->root_class_v . "/PageClasses.pm";
	$res =~ s/::/\//g;
	return $res;
}

sub is_in_manifest { return undef; }

sub template { return <<'ENDS' };
use strict;
use warnings FATAL => 'all';

package [% root_class_v %]::PageClasses;
use base 'Apache::SWIT::Subsystem::Base';

sub classes_for_inheritance { return qw(); }

1;
ENDS

1;
