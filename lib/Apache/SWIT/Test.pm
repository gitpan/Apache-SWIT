use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test;
use base 'Class::Accessor';
use Apache::FakeRequest;
use Apache::SWIT::Test::Mechanize;
use Apache::SWIT::Test::Request;
use HTML::Tested::Test;
use Test::More;

__PACKAGE__->mk_accessors(qw(mech fake_request session));

sub new {
	my ($class, $args) = @_;
	$args ||= {};
	if ($ENV{SWIT_HAS_APACHE}) {
		$args->{mech} = Apache::SWIT::Test::Mechanize->new;
	}
	if ($args->{session_class}) {
		$args->{session} = $args->{session_class}->new;
	}
	return $class->SUPER::new($args);
}

sub _direct_render {
	my ($self, $handler_class, %args) = @_;
	my $r = $self->fake_request || Apache::SWIT::Test::Request->new;
	$r->_param($args{param}) if $args{param};
	return $handler_class->swit_render($r, $self->session);
}

sub _do_swit_update {
	my ($self, $handler_class, $r) = @_;
	my @res = $handler_class->swit_update($r, $self->session);
	my $new_r = Apache::SWIT::Test::Request->new;
	$new_r->parse_url($res[0]);
	$self->fake_request($new_r);
	return @res;
}

sub _direct_update {
	my ($self, $handler_class, %args) = @_;
	my $r = Apache::SWIT::Test::Request->new({ _param => $args{fields} });
	return $self->_do_swit_update($handler_class, $r);
}

sub _mech_render {
	my ($self, $handler_class, %args) = @_;
	$self->mech->get_base($args{base_url}) if $args{base_url};
	return $self->mech->content;
}

sub _mech_update {
	my ($self, $handler_class, %args) = @_;
	$self->mech->submit_form(%args);
	return $self->mech->content;
}

sub _direct_ht_render {
	my ($self, $handler_class, %args) = @_;
	my @res = $self->_direct_render($handler_class, %args);
	return HTML::Tested::Test->check_stash(
			$handler_class->ht_root_class, $res[1], $args{ht});
}

sub _mech_ht_render {
	my ($self, $handler_class, %args) = @_;
	my $content = $self->_mech_render($handler_class, %args);
	return HTML::Tested::Test->check_text(
			$handler_class->ht_root_class, $content, $args{ht});
}

sub _direct_ht_update {
	my ($self, $handler_class, %args) = @_;
	my $r = Apache::SWIT::Test::Request->new({ _param => $args{fields} });
	HTML::Tested::Test->convert_tree_to_param(
			$handler_class->ht_root_class, $r, $args{ht});
	return $self->_do_swit_update($handler_class, $r);
}

sub _mech_ht_update {
	my ($self, $handler_class, %args) = @_;
	my $r = Apache::SWIT::Test::Request->new({ _param => $args{fields} });
	HTML::Tested::Test->convert_tree_to_param(
			$handler_class->ht_root_class, $r, $args{ht});
	$args{fields} = $r->_param;
	delete $args{ht};
	return $self->_mech_update($handler_class, %args);
}

sub _make_test_function {
	my ($class, $handler_class, $op) = @_; 
	return sub {
		my ($self, %a) = @_;
		my $f = $self->mech ? "_mech_$op" : "_direct_$op";
		return $self->$f($handler_class, %a);
	};
}

sub make_aliases {
	my ($class, %args) = @_;
	my %trans = (r => 'render', u => 'update');
	while (my ($n, $v) = each %args) {
		no strict 'refs';
		while (my ($f, $t) = each %trans) {
			my $func = "$n\_$f";
			*{ "$class\::$func" } = $class->_make_test_function($v, $t);
			*{ "$class\::ht_$func" } = 
				$class->_make_test_function($v, "ht_$t");
		}
		my $r_func = "ht_$n\_r";
		*{ "$class\::ok_$r_func" } = sub {
			is_deeply([ shift()->$r_func(@_) ], []);
		};
	}
}

1;
