use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Request;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw(_param _pnotes));

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

sub pnotes {
	my ($self, $name, $val) = @_;
	$self->_pnotes({}) unless $self->_pnotes;
	return $self->_pnotes->{$name} unless scalar(@_) > 2;
	$self->_pnotes->{$name} = $val;
}

1;
