use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Apache;
use base 'Apache::TestRunPerl';
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use File::Path qw(rmtree);
use File::Temp qw(tempdir);
use File::Slurp;
use Test::TempDatabase;

my ($_sess_dir, $_pid);

sub Switch_Dir_Vars {
	my ($from, $to, $dir, @vars) = @_;
	my $s = read_file($from);
	$s =~ s/$_[^\n]+/$_ $dir\/$_/ for @vars;
	write_file($to, $s);
}

sub Check_For_Run_Server {
	my $argv = shift;
	my $rshp = $ENV{__APACHE_SWIT_RUN_SERVER__} or return;
	my ($h, $p) = split(/:/, $rshp);
	return unless ($h && $p);
	push @$argv, "-servername", $h, "-port", $p;
}

sub swit_run {
	my ($class, $from, $to, @vars) = @_;
	my $non_config_func = (@vars && ref($vars[0])) ? shift(@vars) : undef;
	push @vars, 'SWITSessionsDir';
	my $top_dir = abs_path(dirname($0) . "/../");

	my $not_config = (@ARGV && $ARGV[0] ne '-config');
	push @ARGV, '-top_dir', $top_dir;
	my $cf_dir = "$top_dir/t/conf";
	Check_For_Run_Server(\@ARGV);

	if ($not_config) {
		$_sess_dir = tempdir('/tmp/apache_swit_dirs_XXXXXX'); 
		mkdir "$_sess_dir/$_" for @vars;

		Switch_Dir_Vars("$cf_dir/$from", "$cf_dir/$to", $_sess_dir
				, @vars);
		$_pid = $$;
		$ENV{SWIT_TEST_DIR} = $_sess_dir;
		$non_config_func->() if $non_config_func;
	}

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

END {
	return unless ($_sess_dir && $_pid && $_pid == $$);
	rmtree($_sess_dir);
}

1;
