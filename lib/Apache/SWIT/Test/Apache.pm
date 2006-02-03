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

sub Run {
	my ($from, $to) = @_;
	my $top_dir = abs_path(dirname($0) . "/../");

	my $not_config = ($ARGV[0] !~ /^-\w+$/);
	push @ARGV, '-top_dir', $top_dir;

	if ($not_config) {
		$_sess_dir = tempdir('/tmp/apache_swit_sessions_XXXXXX'); 
		`chown nobody $_sess_dir` unless $<;

		my $cf_dir = "$top_dir/t/conf/";
		my $s = read_file("$cf_dir/$from");
		$s =~ s/SWITSessionsDir[^\n]+/SWITSessionsDir $_sess_dir/;
		write_file("$cf_dir/$to", $s);
		$_pid = $$;
	}

	Apache::TestRunPerl->new->run(@ARGV);
}

END {
	return unless ($_sess_dir && $_pid && $_pid == $$);
	rmtree($_sess_dir);
}

1;
