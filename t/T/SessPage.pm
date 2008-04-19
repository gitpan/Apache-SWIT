use strict;
use warnings FATAL => 'all';

package T::SessPage;
use base 'Apache::SWIT::HTPage';
use HTML::Tested qw(HTV);

sub swit_startup {
	shift()->ht_make_root_class->ht_add_widget(HTV."::EditBox", 'persbox');
}

sub swit_template_config {
	my $res = shift()->SUPER::swit_template_config(@_);
	$res->{VARIABLES}->{moo} = 'moo is foo';
	return $res;
}

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
