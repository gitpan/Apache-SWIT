use strict;
use warnings FATAL => 'all';

package T::DBPage::DB;
use base 'Apache::SWIT::DB::Base';
__PACKAGE__->set_up_table('dbp');

package T::DBPage::Root;
use base 'HTML::Tested::ClassDBI';
use HTML::Tested qw(HTV);

__PACKAGE__->ht_add_widget(HTV."::Hidden", id => cdbi_bind => 'Primary');
__PACKAGE__->ht_add_widget(HTV."::EditBox", val => cdbi_bind => '');
__PACKAGE__->bind_to_class_dbi("T::DBPage::DB");

package T::DBPage;
use base 'Apache::SWIT::HTPage';

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->cdbi_load;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	$root->cdbi_create_or_update;
	return $root->ht_make_query_string("r", "id");
}

1;
