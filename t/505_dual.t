use strict;
use warnings FATAL => 'all';

use Test::More tests => 12;
use File::Slurp;
use Test::TempDatabase;
use Cwd;

Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $cwd = getcwd;

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;
$mt->run_modulemaker_and_chdir;

is(system("$cwd/scripts/swit_init"), 0);
isnt(-f "conf/swit.yaml", undef);
unlike(read_file("lib/TTT/UI/Index.pm"), qr/ht_root_class/);

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

append_file("lib/TTT/UI/Index.pm", <<ENDS);
use File::Slurp;
sub swit_startup {
	append_file("$td/swit_startup_test", sprintf("\%d \%s \%s\n"
			, \$\$, \$0, (caller)[1]));
}
ENDS

my $res = `perl Makefile.PL && make test_dual 2>&1`;
like($res, qr/030_load/);
like($res, qr/success/);
unlike($res, qr/Fail/);
unlike($res, qr/010_db/);
isnt(-f "A", undef) or diag($res);
isnt(-f "D", undef);

my $sws = read_file("$td/swit_startup_test");
like($sws, qr/Test\.pm/);
like($sws, qr/httpd\.conf/);

chdir '/';
