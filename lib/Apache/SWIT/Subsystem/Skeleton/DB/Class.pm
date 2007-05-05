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

__PACKAGE__->set_up_table('[% table_v %]', { ColumnGroup => 'Essential' });

sub swit_startup { }

1;
ENDS

1;

