use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::Test'); }

is($ENV{SWIT_HAS_APACHE}, 1);

my $t = Apache::SWIT::Test->new;
ok($t->mech);
$t->mech_get_base("/test/basic_handler");
is($t->mech->content, "hhhh");

$t->mech_get_base("/test/swit/r");
like($t->mech->content, qr/hello world/);

my $td = tempdir("/tmp/swit_basic_XXXXXXX", CLEANUP => 1);
$t->mech->submit_form(fields => { file => "$td/fff" });

# Redirected to res handler
is($t->mech->content, "hhhh\n");
ok(-f "$td/fff");
