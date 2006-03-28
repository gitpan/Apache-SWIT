use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::FileWriter;
use base 'Class::Data::Inheritable', 'Class::Accessor';
use Template;
use File::Slurp;

__PACKAGE__->mk_classdata('Files', {});
__PACKAGE__->mk_accessors(qw(root_dir));

sub new {
	my $self = shift()->SUPER::new(@_);
	$self->{root_dir} ||= '.';
	return $self;
}

sub _normalize_options {
	my ($self, $orig_opts, $new_opts) = @_;
	my %res = map { $_, 
		exists($new_opts->{$_}) ? $new_opts->{$_} : $orig_opts->{$_}
	} (keys(%$orig_opts), keys(%$new_opts));
	return \%res;
}

sub _write_file {
	my ($self, $n, $vars, $new_opts) = @_;
	my $opts = $self->_normalize_options($self->Files->{$n}, $new_opts);
	my $t = Template->new({ OUTPUT_PATH => $self->root_dir })
			or die "No template";
	$t->process(\$opts->{contents}, $vars, $opts->{path})
		or die "No result for $n: " . $t->error;

	write_file($self->root_dir . "/MANIFEST", { append => 1 }
			, "\n" . $opts->{path}) if $opts->{manifest};
}

sub _mangle_name_to_path {
	my ($class, $n) = @_;
	my $p = $$n;
	$$n = lc($p);
	$$n =~ s/[\.\/]/_/g;
	return $p;
}

sub add_file {
	my ($class, $opts, $contents) = @_;
	my $n = $opts->{name} or die "No name found";
	$opts->{contents} ||= $contents;
	$opts->{path} ||= $class->_mangle_name_to_path(\$n);
	$class->Files->{$n} = $opts;
	no strict 'refs';
	*{ "$class\::write_$n" } = sub {
		shift()->_write_file($n, @_);
	};
}

1;
