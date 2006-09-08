use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Manifest;
use base 'Exporter';
use File::Slurp;
use File::Basename qw(dirname);
use File::Path;
use ExtUtils::Manifest;

our @EXPORT = qw(swmani_filter_out swmani_write_file mkpath_write_file
		swmani_dual_tests);

sub swmani_filter_out {
	my $file = shift;
	my @lines = grep { !(/$file/) } read_file('MANIFEST');
	write_file('MANIFEST', join("", @lines));
}

sub mkpath_write_file {
	my ($f, $str) = @_;
	mkpath(dirname($f));
	write_file($f, $str);
}

sub swmani_write_file {
	my ($f, $str) = @_;
	die "Cowardly refusing to overwrite $f" if -f $f;
	mkpath_write_file($f, $str);
	-f 'MANIFEST' ?  ExtUtils::Manifest::maniadd({ $f => "" })
			: write_file('MANIFEST', "$f\n");
}

sub swmani_dual_tests {
	my $mf = ExtUtils::Manifest::maniread();
	return grep { /t\/dual\/.+\.t$/ } keys %$mf;
}

1;
