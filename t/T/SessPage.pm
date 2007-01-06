use strict;
use warnings FATAL => 'all';

package T::SessPage::Root;
use base 'HTML::Tested';
use HTML::Tested qw(HTV);
__PACKAGE__->ht_add_widget(HTV."::EditBox", 'persbox');

package T::SessPage;
use base 'Apache::SWIT::HTPage';


sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->persbox($r->pnotes('SWITSession')->get_persbox);
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	$r->pnotes('SWITSession')->set_persbox($root->persbox);
	return '/test/sess_page/r';
}

1;
