use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Scaffold::Form;
use base qw(Apache::SWIT::Maker::Skeleton::Scaffold::Form
		Apache::SWIT::Subsystem::Skeleton::Scaffold::Base);

sub template { return <<'ENDS'; }
use strict;
use warnings FATAL => 'all';

package [% class_v %]::Root;
use base 'HTML::Tested::ClassDBI';

package [% class_v %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub on_inheritance_end {
	my $class = shift;
	my $rc = $class->ht_root_class;
	$rc->make_tested_hidden('ht_id', cdbi_bind => 'Primary');
	$rc->make_tested_submit('submit_button', default_value => 'Submit');
	$rc->make_tested_submit('delete_button', default_value => 'Delete');
	$rc->make_tested_form(form => default_value => u => children => [[% FOREACH fields_v %]
	[% field %] => edit_box => { cdbi_bind => '' },[% END %]
]);
	$rc->bind_to_class_dbi($class->main_subsystem_class
			->[% db_class_v %]);
	$rc->load_db_constraints;
}

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
