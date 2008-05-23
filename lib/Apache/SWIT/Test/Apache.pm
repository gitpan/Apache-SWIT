use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Apache;
use base 'Apache::TestRunPerl';
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Test::TempDatabase;
use File::Slurp;

sub Check_For_Run_Server {
	my $argv = shift;
	my $rshp = $ENV{__APACHE_SWIT_RUN_SERVER__} or return;
	my ($h, $p) = split(/:/, $rshp);
	return unless ($h && $p);
	push @$argv, "-servername", $h, "-port", $p;
}

sub swit_run {
	my ($class, $non_config_func) = @_;
	my $top_dir = abs_path(dirname($0) . "/../");

	my $not_config = (@ARGV && $ARGV[0] ne '-config');
	push @ARGV, '-top_dir', $top_dir;
	my $cf_dir = "$top_dir/t/conf";
	Check_For_Run_Server(\@ARGV);

	$non_config_func->() if ($non_config_func && $not_config);

	$ENV{SWIT_HAS_APACHE} = 1;
	__PACKAGE__->new->run(@ARGV);
}

sub run_tests {
	return shift()->SUPER::run_tests(@_)
		unless $ENV{__APACHE_SWIT_RUN_SERVER__};
	print STDERR "# Server url is http://"
			. Apache::TestRequest::hostport ."\n";
	print STDERR "# Press Enter to finish ...\n";
	readline(\*STDIN);
}

sub configure {
	shift()->SUPER::configure(@_);
	return unless $ENV{APACHE_SWIT_PROFILE};
	my $cf = read_file('t/conf/httpd.conf');
	$cf =~ s/PerlSwitches/#/g;
	write_file('t/conf/httpd.conf', "$cf\n" . <<ENDS);
<Perl>
        require Apache::DB;
        Apache::DB->init;
</Perl>
PerlModule Apache::DProf
ENDS
}

1;
