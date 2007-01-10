use strict;
use warnings FATAL => 'all';

use Test::More tests => 18;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Slurp;
use Apache::SWIT::Test::Utils;

BEGIN { use_ok('Apache::SWIT::Test'); }

eval { Apache::SWIT::Test->new; };
like($@, qr/do_startup/);

Apache::SWIT::Test->do_startup("AA_ROOT");
is(HTV(), 'HTML::Tested::Value');
is(HT(), 'HTML::Tested');
is(Apache::SWIT::Test->root_env_var, 'AA_ROOT');
is($ENV{SWIT_HAS_APACHE}, 1);
ok($ENV{AA_ROOT});
ok(-f $ENV{AA_ROOT} . "/conf/seal.key");

my $s_up = $ENV{AA_ROOT} . "/conf/startup.pl";
ok(-f $s_up);
like(read_file($s_up), qr/Seal/);

my $t = Apache::SWIT::Test->new;
like($0, qr/001_basic/);
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

like(ASTU_Read_Error_Log(), qr/normal operations/);
like(ASTU_Read_Access_Log(), qr/GET/);
