use lib 'lib';
use Apache::SWIT::Test::Apache;

Apache::SWIT::Test::Apache::Run('extra.conf.swit', 'extra.conf.in');
