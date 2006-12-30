use strict;
use warnings FATAL => 'all';

package T::HTPage::Root;
use base 'HTML::Tested';
use HTML::Tested qw(HTV);

__PACKAGE__->ht_add_widget(HTV, 'hello');
__PACKAGE__->ht_add_widget(HTV, 'v1');
__PACKAGE__->ht_add_widget(HTV."::Upload", 'up');
__PACKAGE__->ht_add_widget(HTV."::Upload", 'inv_up');
__PACKAGE__->ht_add_widget(HTV."::EditBox", 'file');
__PACKAGE__->ht_add_widget(HTV."::Hidden", 'hid', is_sealed => 1);

package T::HTPage;
use base 'Apache::SWIT::HTPage';
use File::Slurp;

sub ht_root_class { return 'T::HTPage::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->hello('world');
	$root->hid($root->hid || 'secret');
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	my $f = $root->file or die "No file is given";
	my $up = $r->upload('up');
	my $res = $up ? $up->filename : "0";
	write_file($f, "$res\n" . read_file($root->up));
	return '/test/basic_handler';
}

1;
