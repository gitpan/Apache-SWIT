use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Scaffold;
use base 'Apache::SWIT::Maker::Skeleton';
use Apache::SWIT::Maker::Conversions;

__PACKAGE__->mk_accessors(qw(columns table));

sub table_class_v { return conv_table_to_class(shift()->table); }
sub col1_v { return shift()->columns->[0]; }
sub list_name_v { return shift()->table . "_list"; }

sub fields_v {
	my $cols = shift()->columns;
	return [ map { { field => $_, title => conv_table_to_class($_) } }
			@$cols ];
}

1;
