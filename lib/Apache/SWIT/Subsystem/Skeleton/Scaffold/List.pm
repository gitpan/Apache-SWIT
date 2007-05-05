use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Scaffold::List;
use base qw(Apache::SWIT::Maker::Skeleton::Scaffold::List);

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

sub swit_startup {
	my $class = shift;
	my $rc = $class->ht_root_class;
	my $rci = $rc . '::Item';
	$rci->ht_add_widget(::HTV."::Link", '[% col1_v %]'
		, href_format => '../info/r?edit_link=%s'
		, cdbi_bind => [ [% col1_v %] => 'Primary' ]
		, column_title => '[% link_title_v %]'
		, 0 => { isnt_sealed => 1 });
[% FOREACH list_fields_v %]$rci->ht_add_widget(::HTV."::Marked", '[% field %]'
		, cdbi_bind => '', column_title => '[% title %]');
[% END %]
	$rci->bind_to_class_dbi("[% db_class_v %]");

	$rc->ht_add_widget(::HTV."::Form", 'form', default_value => 'u');
	$rc->ht_add_widget(::HT."::List", '[% list_name_v %]', $rc . '::Item'
		, render_table => 1);
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
