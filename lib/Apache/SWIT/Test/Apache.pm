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

sub Switch_Sessions_Dir {
	my ($from, $to, $dir) = @_;
	my $s = read_file($from);
	$s =~ s/SWITSessionsDir[^\n]+/SWITSessionsDir $dir/;
	write_file($to, $s);
}

sub Run {
	my ($from, $to) = @_;
	my $top_dir = abs_path(dirname($0) . "/../");

	my $not_config = ($ARGV[0] !~ /^-\w+$/);
	push @ARGV, '-top_dir', $top_dir;

	if ($not_config) {
		$_sess_dir = tempdir('/tmp/apache_swit_sessions_XXXXXX'); 
		`chown nobody $_sess_dir` unless $<;

		my $cf_dir = "$top_dir/t/conf";
		Switch_Sessions_Dir("$cf_dir/$from", "$cf_dir/$to", $_sess_dir);
		$_pid = $$;
	}

	$ENV{SWIT_HAS_APACHE} = 1;
	Apache::TestRunPerl->new->run(@ARGV);
}

END {
	return unless ($_sess_dir && $_pid && $_pid == $$);
	rmtree($_sess_dir);
}

1;
