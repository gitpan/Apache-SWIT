use lib 'lib';
use Apache::SWIT::Test::Apache;
use File::Slurp;
use File::Basename qw(dirname);
use File::Path qw(mkpath);

mkpath(dirname($0) . "/../blib/conf");
write_file(dirname($0) . "/../blib/conf/seal.key", "boo boo boo");
Apache::SWIT::Test::Apache::Run('extra.conf.swit', 'extra.conf.in');
