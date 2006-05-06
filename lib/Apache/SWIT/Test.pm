use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test;
use base 'Class::Accessor', 'Class::Data::Inheritable';
use Apache::SWIT::Test::Mechanize;
use HTML::Tested::Test::Request;
use HTML::Tested::Test;
use Test::More;

__PACKAGE__->mk_accessors(qw(mech fake_request session));
__PACKAGE__->mk_classdata('root_location');

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
	my $r = $self->fake_request || HTML::Tested::Test::Request->new;
	$r->_param($args{param}) if $args{param};
	$r->pnotes('SWITSession', $self->session);
	return $handler_class->swit_render($r);
}

sub _do_swit_update {
	my ($self, $handler_class, $r) = @_;
	$r->pnotes('SWITSession', $self->session);
	my @res = $handler_class->swit_update($r);
	my $new_r = HTML::Tested::Test::Request->new;
	$new_r->parse_url($res[0]);
	$self->fake_request($new_r);
	return @res;
}

sub _make_test_request {
	my ($self, $args) = @_;
	my $r = HTML::Tested::Test::Request->new({ _param => $args->{fields} });
	my $b = delete $args->{button};
	$r->param($b->[0], $b->[1]) if ($b);
	return $r;
}

sub _direct_update {
	my ($self, $handler_class, %args) = @_;
	my $r = $self->_make_test_request(\%args);
	return $self->_do_swit_update($handler_class, $r);
}

sub _mech_render {
	my ($self, $handler_class, %args) = @_;
	my $goto = $args{base_url};
	$goto = $self->root_location . "/" . $args{url_to_make} 
			if ($args{make_url});
	$self->mech->get_base($goto) if $goto;
	return $self->mech->content;
}

sub _mech_update {
	my ($self, $handler_class, %args) = @_;
	delete $args{url_to_make};
	my $b = delete $args{button};
	$args{button} = $b->[0] if $b;
	delete $args{fields}->{$_} for map { $_->name } grep { $_->readonly }
		$self->mech->current_form->inputs;
	$self->mech->submit_form(%args);
	return $self->mech->content;
}

sub _direct_ht_render {
	my ($self, $handler_class, %args) = @_;
	my $res = $self->_direct_render($handler_class, %args);
	return HTML::Tested::Test->check_stash(
			$handler_class->ht_root_class, $res, $args{ht});
}

sub _mech_ht_render {
	my ($self, $handler_class, %args) = @_;
	my $content = $self->_mech_render($handler_class, %args);
	return HTML::Tested::Test->check_text(
			$handler_class->ht_root_class, $content, $args{ht});
}

sub _direct_ht_update {
	my ($self, $handler_class, %args) = @_;
	my $r = $self->_make_test_request(\%args);
	HTML::Tested::Test->convert_tree_to_param(
			$handler_class->ht_root_class, $r, $args{ht});
	return $self->_do_swit_update($handler_class, $r);
}

sub _mech_ht_update {
	my ($self, $handler_class, %args) = @_;
	my $r = HTML::Tested::Test::Request->new({ _param => $args{fields} });
	HTML::Tested::Test->convert_tree_to_param(
			$handler_class->ht_root_class, $r, $args{ht});
	$args{fields} = $r->_param;
	delete $args{ht};
	return $self->_mech_update($handler_class, %args);
}

sub _make_test_function {
	my ($class, $handler_class, $op, $url) = @_; 
	return sub {
		my ($self, %a) = @_;
		$a{url_to_make} = $url;
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
			$func =~ s/\//_/g;
			my $url = "$n/$f";
			*{ "$class\::$func" } = 
				$class->_make_test_function($v, $t, $url);
			*{ "$class\::ht_$func" } = 
				$class->_make_test_function($v, "ht_$t", $url);
		}
		my $r_func = "ht_$n\_r";
		$r_func =~ s/\//_/g;
		*{ "$class\::ok_$r_func" } = sub {
			is_deeply([ shift()->$r_func(@_) ], []);
		};
	}
}

1;
