use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Makefile;
use base 'Apache::SWIT::Maker::Makefile';
use Apache::SWIT::Maker::GeneratorsQueue;
use Apache::SWIT::Maker::Manifest;
use File::Slurp;
use Data::Dumper;

sub make_this_subsystem_dumps {
	my $self = shift;
	my $gq = Apache::SWIT::Maker::GeneratorsQueue->new;
	my $orig_tree = Apache::SWIT::Maker::Config->instance;
	undef $Apache::SWIT::Maker::Config::_instance;
	while (my ($n, $v) = each %{ $orig_tree->{pages} }) {
		$orig_tree->{pages}->{$n} = $gq->run('dump_page_entry', $v);
	}
	my @dual_tests = map { s#t/dual/##; $_ } swmani_dual_tests();
	my %tests = map {
		my $t = read_file("t/dual/$_");
		($_, $t)
	} @dual_tests;
	$orig_tree->{dumped_tests} = \%tests;
	return (original_tree => $orig_tree);
}

sub do_install {
	my ($class, $from, $to) = @_;
	my %dumps = $class->make_this_subsystem_dumps;
	Apache::SWIT::Maker::FileWriterData->new
			->write_blib_lib_installationcontent_pm({
		dumps => [ map {
			{ name => $_, 'dump' => Dumper($dumps{$_}) }
	} keys %dumps ] });
	$class->install_files("$from/lib", $to);
}

sub _mm_constants {
	return shift()->MY::SUPER::constants(\@_);
}

1;
