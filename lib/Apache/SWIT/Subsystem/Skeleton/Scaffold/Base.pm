use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Scaffold::Base;

sub db_class_v {
	my $res = lc("db_" . shift()->table_class_v) . "_class";
	$res =~ s/::/_/g;
	return $res;
}

1;
