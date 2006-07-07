use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Apache;
use Apache::TestRunPerl;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use File::Path qw(rmtree);
use File::Temp qw(tempdir);
use File::Slurp;

my ($_sess_dir, $_pid);

sub Switch_Dir_Vars {
	my ($from, $to, $dir, @vars) = @_;
	my $s = read_file($from);
	$s =~ s/$_[^\n]+/$_ $dir\/$_/ for @vars;
	write_file($to, $s);

	if ($s =~ /Seal->instance\(\'([^\']+)/) {
		$ENV{APACHE_SWIT_HT_SEAL} = $1;
	}
}

sub Run {
	my ($from, $to, @vars) = @_;
	push @vars, 'SWITSessionsDir';
	my $top_dir = abs_path(dirname($0) . "/../");

	my $not_config = ($ARGV[0] !~ /^-\w+$/);
	push @ARGV, '-top_dir', $top_dir;

	if ($not_config) {
		$_sess_dir = tempdir('/tmp/apache_swit_dirs_XXXXXX'); 
		mkdir "$_sess_dir/$_" for @vars;

		my $cf_dir = "$top_dir/t/conf";
		Switch_Dir_Vars("$cf_dir/$from", "$cf_dir/$to", $_sess_dir
				, @vars);
		`chown -R nobody $_sess_dir` unless $<;
		$_pid = $$;
		$ENV{SWIT_TEST_DIR} = $_sess_dir;
	}

	$ENV{SWIT_HAS_APACHE} = 1;
	Apache::TestRunPerl->new->run(@ARGV);
}

END {
	return unless ($_sess_dir && $_pid && $_pid == $$);
	rmtree($_sess_dir);
}

1;
