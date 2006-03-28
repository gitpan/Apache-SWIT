use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Generator;
use base 'Apache::SWIT::Maker::GeneratorBase';
use File::Slurp;

sub location_section_prolog {
	my ($self, $res, $loc, $e) = @_;
	my $ec = $e->{class};
	$res =~ s/PerlModule $ec//;
	$e->{class} = "T::$ec";
	return $res;
}

sub location_section_epilogue {
	my ($self, $res, $loc, $e) = @_;
	$e->{class} =~ s/^T:://;
	return '';
}

sub dump_page_entry {
	my ($self, $res, $v) = @_;
	my $rc = $self->tree->{root_class};
	my $tt_file = $v->{entry_points}->{r}->{template};
	$v->{class} =~ s/^$rc\:://;
	$v->{file} = read_file($tt_file);
	$tt_file =~ s#^templates/##;
	$v->{entry_points}->{r}->{template} = $tt_file;
	return $v;
}

sub install_page_entry {
	my ($self, $res, $v, $module) = @_;
	my $lcm = lc($module);
	my $tt_file = $v->{entry_points}->{r}->{template} =
		"templates/$lcm/" . $v->{entry_points}->{r}->{template};
	$v->{class} = $self->tree->{root_class} ."::$module\::" . $v->{class};
	$v->{do_not_use} = 1;
	Apache::SWIT::Maker::mani_wf($tt_file, $v->{file});
	delete $v->{file};
	return $v;
}

sub httpd_conf_start {
	my ($self, $res) = @_;
	my $sc = $self->tree->{session_class};
	$res =~ s/$sc/T::$sc/g;
	return $res;
}

1;
