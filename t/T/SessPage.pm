use strict;
use warnings FATAL => 'all';

package T::SessPage::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_edit_box('persbox');

package T::SessPage;
use base 'Apache::SWIT::HTPage';

sub ht_root_class { return 'T::SessPage::Root'; }

sub ht_swit_render {
	my ($class, $r, $root, $session) = @_;
	$root->persbox($session->get_persbox);
	return ($r->server_root_relative('templates/sess_page.tt'), $root);
}

sub ht_swit_update {
	my ($class, $r, $root, $session) = @_;
	$session->set_persbox($root->persbox);
	return '/test/sess_page/r';
}

1;
