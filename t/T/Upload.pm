use strict;
use warnings FATAL => 'all';

package T::Upload::DB;
use base 'Apache::SWIT::DB::Base';
__PACKAGE__->set_up_table('upt');

package T::Upload::Root;
use base 'HTML::Tested::ClassDBI';
use HTML::Tested qw(HTV);

__PACKAGE__->ht_add_widget(::HTV, id => is_sealed => 1
					=> cdbi_bind => 'Primary');
__PACKAGE__->ht_add_widget(::HTV."::Upload", the_upload => cdbi_upload =>
				'loid');
__PACKAGE__->ht_add_widget(::HTV."::Upload", mime_upload =>
		cdbi_upload_with_mime => 'loid');
__PACKAGE__->ht_add_widget(::HTV, loid => is_sealed => 1 => cdbi_bind => ''
				, cdbi_readonly => 1);
__PACKAGE__->ht_add_widget(::HTV."::Form", form => default_value => 'u');
__PACKAGE__->bind_to_class_dbi("T::Upload::DB");

sub ht_validate { return (); }

package T::Upload;
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
