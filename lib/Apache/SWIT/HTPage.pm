use strict;
use warnings FATAL => 'all';

package Apache::SWIT::HTPage;
use base 'Apache::SWIT';
use HTML::Tested;

sub swit_render {
	my ($class, $r) = @_;
	my $stash = {};
	my $tested = $class->ht_root_class->ht_convert_request_to_tree($r);
	my $root = $class->ht_swit_render($r, $tested);
	$root->ht_render($stash);
	return $stash;
}

sub swit_update {
	my ($class, $r) = @_;
	my $tested = $class->ht_root_class->ht_convert_request_to_tree($r);
	return $class->ht_swit_update($r, $tested);
}

1;
