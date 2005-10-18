use Apache::TestRunPerl;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use File::Path qw(rmtree mkpath);

my $top_dir = abs_path(dirname($0) . "/../../");

# This stupidity is needed to confuse Apache::Test to not chdir
$0 = 'asdhdhdh';

push @ARGV, '-top_dir', $top_dir;

mkpath('/tmp/apache_swit_sessions'); 
Apache::TestRunPerl->new->run(@ARGV);
rmtree('/tmp/apache_swit_sessions');
