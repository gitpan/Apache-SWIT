use strict;
use warnings FATAL => 'all';

use Test::More tests => 9;
use File::Slurp;
use Test::TempDatabase;
use Cwd;

Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $cwd = getcwd;

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->run_modulemaker_and_chdir;

is(system("$cwd/scripts/swit_init"), 0);
isnt(-f "conf/swit.yaml", undef);

write_file('t/dual/030_load.t', <<'ENDS');
use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;
use File::Slurp;

BEGIN { use_ok('T::Test'); };

my $t = T::Test->new;
$t->with_or_without_mech_do(1, sub { ok 1; write_file("A", ""); },
		1, sub { ok 1; write_file("D", ""); });
ENDS

my $res = `perl Makefile.PL && make test_dual 2>&1`;
like($res, qr/030_load/);
like($res, qr/success/);
unlike($res, qr/Fail/);
unlike($res, qr/010_db/);
isnt(-f "A", undef);
isnt(-f "D", undef);

chdir '/';
