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
use HTML::Tested qw(HTV);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub on_inheritance_end {
	my $class = shift;
	my $rc = $class->ht_root_class;
	$rc->ht_add_widget(HTV."::Hidden", 'ht_id', cdbi_bind => 'Primary');
	$rc->ht_add_widget(HTV."::Submit", 'submit_button'
			, default_value => 'Submit');
	$rc->ht_add_widget(HTV."::Submit", 'delete_button'
			, default_value => 'Delete');
	[% FOREACH fields_v %]
	$rc->ht_add_widget(HTV."::EditBox"
			, [% field %] => cdbi_bind => '');[% END %]
	$rc->ht_add_widget(HTV."::Form", form => default_value => 'u');
	$rc->bind_to_class_dbi($class->main_subsystem_class
			->[% db_class_v %]);
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
