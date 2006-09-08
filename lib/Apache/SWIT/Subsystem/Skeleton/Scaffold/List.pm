use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Scaffold::List;
use base qw(Apache::SWIT::Maker::Skeleton::Scaffold::List
		Apache::SWIT::Subsystem::Skeleton::Scaffold::Base);

sub template { return <<'ENDS'; }
use strict;
use warnings FATAL => 'all';

package [% class_v %]::Root::Item;
use base 'HTML::Tested::ClassDBI';

package [% class_v %]::Root;
use base 'HTML::Tested';

package [% class_v %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub on_inheritance_end {
	my $class = shift;
	my $rc = $class->ht_root_class;
	$rc->make_tested_form('form', default_value => 'u');
	$rc->make_tested_list('[% list_name_v %]', $rc . '::Item');
	$rc .= '::Item';
	$rc->make_tested_link('[% col1_v %]'
		, href_format => '../info/r?edit_link=%s'
		, cdbi_bind => [ [% col1_v %] => 'Primary' ]
		, column_title => '[% link_title_v %]');
[% FOREACH list_fields_v %]$rc->make_tested_marked_value('[% field %]'
		, cdbi_bind => '', column_title => '[% title %]');
[% END %]
	$rc->bind_to_class_dbi($class->main_subsystem_class
			->[% db_class_v %]);
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->[% list_name_v %]_containee_do(query_class_dbi => 'retrieve_all');
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
ENDS

1;
