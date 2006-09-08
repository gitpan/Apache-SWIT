use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Scaffold::Info;
use base qw(Apache::SWIT::Maker::Skeleton::Page
		Apache::SWIT::Maker::Skeleton::Scaffold);

sub template { return <<'ENDS'; }
use strict;
use warnings FATAL => 'all';

package [% class_v %]::Root;
use base 'HTML::Tested::ClassDBI';
use [% root_class_v %]::DB::[% table_class_v %];
__PACKAGE__->make_tested_form(form => default_value => u => children => [[% FOREACH fields_v %]
	[% field %] => marked_value => { cdbi_bind => '' },[% END %]
]);
__PACKAGE__->make_tested_link('edit_link'
		, href_format => '../form/r?ht_id=%s'
		, caption => 'Edit', cdbi_bind => [ 'Primary' ]);
__PACKAGE__->bind_to_class_dbi('[% root_class_v %]::DB::[% table_class_v %]');

package [% class_v %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->cdbi_load;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
ENDS

1;
