use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Conversions;
use base 'Exporter';
use File::Slurp;
use Carp;

our @EXPORT = qw(conv_table_to_class conv_make_full_class
		conv_next_dual_test conv_class_to_app_name
		conv_forced_write_file conv_eval_use);

sub _capitalize {
	my ($l, $rest) = ($_[0] =~ /(\w)(\w*)/);
	return uc($l) . $rest;
}

sub conv_table_to_class {
	my $t = shift;
	return join('', map { _capitalize($_) } split('_', $t));
}

sub conv_make_full_class {
	my ($root, $prefix, $class) = @_;
	my $res;
	if ($class =~ s/^$root\:://) {
		$res = $root . "::$class";
	} else {
		$res = $root . "::$prefix\::$class";
	}
	return $res;
}

sub conv_next_dual_test {
	my $max = 0;
	foreach (split("\n", $_[0])) {
		/\/dual\/(\d\d\d).*\.t\b/ or next;
		next if $max > $1;
		$max = $1;
	}
	return sprintf("%03d", $max + 10);
}

sub conv_class_to_app_name {
	my $class = lc(shift);
	$class =~ s/::/_/g;
	return $class;
}

sub conv_forced_write_file {
	my ($to_conf, $str) = @_;

	# ExtUtils::Install changes permissions to readonly
	my $readonly = ! -w $to_conf;
	chmod 0644, $to_conf if $readonly;
	write_file($to_conf, $str);
	chmod 0444, $to_conf if $readonly;
}

sub conv_eval_use {
	my $c = shift;
	eval "use $c";
	confess "Cannot use $c: $@" if $@;
	return $c;
}

1;
