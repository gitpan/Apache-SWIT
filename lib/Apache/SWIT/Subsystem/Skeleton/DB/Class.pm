use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::DB::Class;
use base 'Apache::SWIT::Maker::Skeleton::DB::Class';
use Apache::SWIT::Maker::Config;

sub template { return <<'ENDS' };
use strict;
use warnings FATAL => 'all';

package [% class_v %];
use base 'Apache::SWIT::DB::Base';

sub on_inheritance_end {
	my $class = shift;
	$class->set_up_table('[% table_v %]', { ColumnGroup => 'Essential' });
}

1;
ENDS

1;

