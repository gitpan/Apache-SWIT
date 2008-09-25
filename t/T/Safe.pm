use strict;
use warnings FATAL => 'all';

package T::Safe::DB;
use base 'Apache::SWIT::DB::Base';
__PACKAGE__->set_up_table('safet');

package T::Safe::Root;
use base 'HTML::Tested::ClassDBI';
__PACKAGE__->ht_add_widget(::HTV."::Hidden", 's_id' => cdbi_bind => 'Primary');
__PACKAGE__->ht_add_widget(::HTV."::EditBox", 'name' => cdbi_bind => '');
__PACKAGE__->ht_add_widget(::HTV."::EditBox", 'email' => cdbi_bind => ''
		, constraints => [ [ regexp => '^[^ ]*$' ] ]);
__PACKAGE__->bind_to_class_dbi('T::Safe::DB');

package T::Safe;
use Apache::SWIT::HTPage;
use base 'Apache::SWIT::HTPage::Safe';

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	$root->cdbi_create;
	return "r";
}

1;

