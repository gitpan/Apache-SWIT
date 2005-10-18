use strict;
use warnings FATAL => 'all';

use Test::More tests => 5;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::Test::Mechanize'); }

my $mech = Apache::SWIT::Test::Mechanize->new;
$mech->get_base("/test/basic_handler");
is($mech->content, "hhhh");

$mech->get_base("/test/swit/r");
like($mech->content, qr/hello world/);

my $td = tempdir("/tmp/swit_basic_XXXXXXX", CLEANUP => 1);
$mech->submit_form(fields => { file => "$td/fff" });

# Redirected to res handler
is($mech->content, "hhhh\n");
ok(-f "$td/fff");
