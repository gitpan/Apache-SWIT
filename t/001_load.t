use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;

BEGIN { use_ok( 'Apache::SWIT' );
	use_ok('Apache::SWIT::Test::Request');
}

my $r = Apache::SWIT::Test::Request->new;
$r->parse_url('/test/url?arg=1&b=c');
is_deeply($r->_param, { arg => 1, b => 'c' });
$r->parse_url('/test/url?arg=1&b&c=&d=');
is_deeply($r->_param, { arg => 1, b => '', c => '', d => '' });
