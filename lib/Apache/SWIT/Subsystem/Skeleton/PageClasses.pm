use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::PageClasses;
use base 'Apache::SWIT::Maker::Skeleton';

sub add {
	my $tree = Apache::SWIT::Maker::Config->instance;
	push @{ $tree->{classes_for_inheritance} }, $_[1];
	$tree->save;
}

sub output_file {
	my $res = 'blib/lib/' . shift()->root_class_v . "/PageClasses.pm";
	$res =~ s/::/\//g;
	return $res;
}

sub page_classes_v {
	my $tree = Apache::SWIT::Maker::Config->instance;
	my $rc = $tree->root_class;
	return [ map { s/^$rc\:://; { pc => $_ } } (
			(map { $_->{class} } values %{ $tree->{pages} })
			, @{ $tree->{classes_for_inheritance} }) ];
}

sub is_in_manifest { return undef; }

sub template { return <<'ENDS' };
use strict;
use warnings FATAL => 'all';

package [% root_class_v %]::PageClasses;
use base 'Apache::SWIT::Subsystem::Base';

sub classes_for_inheritance { return qw(
[% FOREACH page_classes_v %]	[% pc %]
[% END %]); }

1;
ENDS

1;
