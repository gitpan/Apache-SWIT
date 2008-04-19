use strict;
use warnings FATAL => 'all';

package T::HTError::Root;

sub ht_validate {
 	return shift()->name eq 'bad' ? ('bad') : ();
}

package T::HTError;
use base 'Apache::SWIT::HTPage';
use HTML::Tested qw(HTV);
use HTML::Tested::Value::PasswordBox;

sub swit_startup {
	my $rc = shift()->ht_make_root_class;
	$rc->ht_add_widget(HTV."::EditBox", 'name');
	$rc->ht_add_widget(HTV."::PasswordBox", 'password');
	$rc->ht_add_widget(HTV, 'error');
	$rc->ht_add_widget(::HTV."::Form", form => default_value => 'u');
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->name("buh");
	return $root;
}

sub ht_swit_validate_die {
	my ($class, $r, $root, $args, $errs) = @_;
	delete $args->{password};
	return "r?error=validie";
}

sub ht_swit_validate {
	my ($class, $r, $root, $args) = @_;
	if ($root->name eq 'foo') {
		delete $args->{password};
		return "r?error=validate";
	}
	return $class->SUPER::ht_swit_validate($r, $root, $args);
}

sub ht_swit_update_die {
	my ($class, $msg, $r, $root, $args) = @_;
	return $class->SUPER::swit_die(@_) unless $msg =~ /Hoho/;
	delete $args->{password};
	return "r?error=updateho";
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return [ Apache2::Const::FORBIDDEN() ] if $root->name eq 'FORBID';
	die "Hoho";
	return "r";
}

1;
