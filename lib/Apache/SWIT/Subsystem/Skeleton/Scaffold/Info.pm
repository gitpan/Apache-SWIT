use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Skeleton::Scaffold::Info;
use base qw(Apache::SWIT::Maker::Skeleton::Scaffold::Info
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
	$rc->make_tested_form(form => default_value => u => children => [[% FOREACH fields_v %]
	[% field %] => marked_value => { cdbi_bind => '' },[% END %]
]);
	$rc->make_tested_link('edit_link'
		, href_format => '../form/r?ht_id=%s'
		, caption => 'Edit', cdbi_bind => [ 'Primary' ]);
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
	return "r";
}

1;
ENDS

1;