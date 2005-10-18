use strict;
use warnings FATAL => 'all';

package Apache::SWIT::HTPage;
use base 'Apache::SWIT';
use HTML::Tested;

sub swit_render {
	my ($class, $r, $session) = @_;
	my $stash = {};
	my $tested = $class->ht_root_class->ht_convert_request_to_tree($r);
	my @res = $class->ht_swit_render($r, $tested, $session);
	$res[1]->ht_render($stash);
	return ($res[0], $stash);
}

sub swit_update {
	my ($class, $r, $session) = @_;
	my $tested = $class->ht_root_class->ht_convert_request_to_tree($r);
	return $class->ht_swit_update($r, $tested, $session);
}

1;
