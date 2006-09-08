use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Scaffold::Form;
use base qw(Apache::SWIT::Maker::Skeleton::Page
		Apache::SWIT::Maker::Skeleton::Scaffold);

sub template { return <<'ENDS'; }
use strict;
use warnings FATAL => 'all';

package [% class_v %]::Root;
use base 'HTML::Tested::ClassDBI';
use [% root_class_v %]::DB::[% table_class_v %];
__PACKAGE__->make_tested_hidden('ht_id', cdbi_bind => 'Primary');
__PACKAGE__->make_tested_submit('submit_button', default_value => 'Submit');
__PACKAGE__->make_tested_submit('delete_button', default_value => 'Delete');
__PACKAGE__->make_tested_form(form => default_value => u => children => [[% FOREACH fields_v %]
	[% field %] => edit_box => { cdbi_bind => '' },[% END %]
]);
__PACKAGE__->bind_to_class_dbi('[% root_class_v %]::DB::[% table_class_v %]');
__PACKAGE__->load_db_constraints;

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
	$root->delete_button
		? $root->cdbi_delete
		: $root->cdbi_create_or_update;
	return "r";
}

1;
ENDS

1;
