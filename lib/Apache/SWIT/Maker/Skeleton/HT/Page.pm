use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::HT::Page;
use base 'Apache::SWIT::Maker::Skeleton::Page';

sub template { return <<'ENDS' };
use strict;
use warnings FATAL => 'all';

package [% class_v %]::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_form(form => default_value => u => children => [
		first => 'marked_value' ]);

package [% class_v %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return __PACKAGE__ . '::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
ENDS

1;

