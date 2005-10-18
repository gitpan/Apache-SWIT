use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Request;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw(_param));

sub server_root_relative {
	return $_[1];
}

sub param {
	my ($self, $name, $val) = @_;
	$self->_param({}) unless $self->_param;
	$self->_param->{$name} = $val if (defined($val));
	return $self->_param->{$name} if ($name);
	return keys %{ $self->_param || {} };
}

sub dir_config {
	return '';
}

sub parse_url {
	my ($self, $url) = @_;
	my ($arg_str) = ($url =~ /\?(.+)/);
	return unless $arg_str;
	my @nvs = split('&', $arg_str);
	my %res = map { my @a = split('=', $_); ($a[0], ($a[1] || '')); } @nvs;
	$self->_param(\%res);
}

1;
