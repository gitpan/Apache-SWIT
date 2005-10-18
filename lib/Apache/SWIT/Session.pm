use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Session;
use Digest::MD5 qw(md5_hex);
use Storable qw(lock_store lock_retrieve);
use Apache::Cookie;

sub begin {
	my ($class, $r) = @_;
	my %args = (_request => $r);
	my %cookies = Apache::Cookie->fetch;
	$args{session_id} = $cookies{$class->cookie_name}->value
		if $cookies{$class->cookie_name};
	my $self = $class->new(%args);
	$self->read_stash;
	return $self;
}

sub end {
	my $self = shift;
	my $cookie = Apache::Cookie->new($self->{_request}, 
			'-name' => $self->cookie_name,
			'-value' => $self->session_id);
	$cookie->bake;
	$self->write_stash;
}

sub new {
	my ($class, %args) = @_;
	$args{session_id} ||= md5_hex(rand(1024) . time() . $$);
	return bless(\%args, $class);
}

sub _get {
	my ($self, $name, $args, $val) = @_;
	my $res = $self->{_stash}->{$name};
	return unless defined($res);
	$res = $args->{inflate}->($res) if $args->{inflate};
	return $res;
}

sub _delete_children {
	my ($self, $args) = @_;
	for my $d (@{ $args->{children} || [] }) {
		my $f = "delete_$d";
		$self->$f;
	}
}

sub _set {
	my ($self, $name, $args, $val) = @_;
	$self->{_stash}->{$name} = $args->{deflate} ? $args->{deflate}->($val) : $val;
	$self->_delete_children($args);
}

sub _delete {
	my ($self, $name, $args) = @_;
	my $res = delete $self->{_stash}->{$name};
	$self->_delete_children($args);
	return $res;
}

sub add_var {
	my ($class, $name, %args) = @_;
	no strict 'refs';
	*{ "$class\::get_$name" } = sub {
		return shift()->_get($name, \%args, @_);
	};
	*{ "$class\::set_$name" } = sub {
		return shift()->_set($name, \%args, @_);
	};
	*{ "$class\::delete_$name" } = sub {
		return shift()->_delete($name, \%args, @_);
	};
	*{ "$class\::$name\_args" } = sub { return \%args; };

	$args{children} = [] unless $args{children};

	for my $d (@{ $args{depends_on} || [] }) {
		my $p_args = "$d\_args";
		push @{ $class->$p_args->{children} }, $name;
	}
}

sub session_id { return shift()->{session_id}; }

sub write_stash {
	my $self = shift;
	my $file = $self->sessions_dir . "/" . $self->session_id;
	lock_store($self->{_stash}, $file);
}

sub read_stash {
	my $self = shift;
	my $file = $self->sessions_dir . "/" . $self->session_id;
	$self->{_stash} = -f $file ? lock_retrieve($file) : {};
}


1;
