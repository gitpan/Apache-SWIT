use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::GeneratorsQueue;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(tree generators));

sub new {
	my ($class, $args) = @_;
	goto OUT if ($args && $args->{tree});

	my $tree = YAML::LoadFile('conf/swit.yaml') 
				or die "No conf/swit.yaml found";
	my $gclasses = $args->{generator_classes} ? 
			$args->{generator_classes} : $tree->{generators};
	my @gens;
	for my $c (@$gclasses) {
		eval "use $c";
		die "Unable to use $c : $@" if $@;
		push @gens, $c->new({ tree => $tree });
	}
	$args = { tree => $tree, generators => \@gens };
OUT:	
	return $class->SUPER::new($args);
}

sub run {
	my ($self, $func, @args) = @_;
	my $res;
	for my $g (@{ $self->generators }) {
		next unless $g->can($func);
		$res = $g->$func($res, @args);
	}
	return $res;
}

1;

