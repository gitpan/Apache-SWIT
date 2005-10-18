use strict;
use warnings FATAL => 'all';

package T::HTPage::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_value('hello');
__PACKAGE__->make_tested_value('v1');
__PACKAGE__->make_tested_edit_box('file');

package T::HTPage;
use base 'Apache::SWIT::HTPage';
use T::Session;

sub ht_root_class { return 'T::HTPage::Root'; }

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->hello('world');
	return ($r->server_root_relative('templates/htpage.tt'), $root);
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	my $f = $root->file or die "No file is given";
	open(my $fh, ">$f") or die "Unable to open $f";
	close $fh;
	return '/test/basic_handler';
}

1;
