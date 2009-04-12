use strict;
use warnings FATAL => 'all';

use Test::More tests => 25;
use Test::TempDatabase;
use File::Slurp;
use Apache::SWIT::Test::Utils;
use File::Copy;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');
ok(-f 'lib/TTT/DB/Schema.pm');

$mt->replace_in_file('lib/TTT/UI/Index.pm', "first\'"
		, "first\', is_sealed => 1");

my $make = "perl Makefile.PL && make";
my $res = `$make test_direct 2>&1`;
like($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/HT_SEALED/);

$mt->replace_in_file('t/dual/001_load.t', 'first', 'HT_SEALED_first');
$res = `make test_direct 2>&1`;
unlike($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/success/);

write_file('t/dual/030_load.t', <<'ENDS');
use strict;
use warnings FATAL => 'all';
use File::Slurp;

use Test::More tests => 6;

BEGIN {
        use_ok('T::Test');
};

my $t = T::Test->new;
is($t->session->request->uri, '/ttt/');

$t->ok_ht_index_r(make_url => 1, param => { HT_SEALED_first => 12 }
		, ht => { HT_SEALED_first => 12 });
$t->with_or_without_mech_do(2, sub {
	$t->mech->content =~ /First:.*--> (\w+)/;
	my $curf = $1;
	is(HTML::Tested::Seal->instance->decrypt($curf), 12);
	if (-f 'curf') {
		my $oldf = read_file('curf');
		is(HTML::Tested::Seal->instance->decrypt($oldf), 12);
	} else {
		write_file('curf', $curf);
		isnt(-f 'curf', undef);
	}
});

package M;
use base 'WWW::Mechanize';

sub get {
	Test::More::diag("MGET");
	shift()->SUPER::get(@_);
}

package main;

$t->mech(M->new) if $t->mech;
$t->ok_get('www/main.css');
ENDS

append_file('t/dual/001_load.t', <<'ENDS');
if ($t->mech) {
	$t->mech_get_base('/ttt/www/main.css');
	diag($t->mech->content);
}
ENDS

$res = `make test_apache 2>&1`;
unlike($res, qr/Failed/) or ASTU_Wait;
like($res, qr/success/);
like($res, qr/CSS/);
like($res, qr/MGET/);
is(-d 't/logs/dprof', undef);

ok(copy("blib/conf/seal.key", "conf/seal.key"));
$res = `make realclean && perl Makefile.PL 2>&1`;
is($?, 0) or ASTU_Wait($res);

my $pros = 'APACHE_SWIT_PROFILE=1 make test_apache '
		. 'APACHE_TEST_FILES=t/dual/030_load.t 2>&1';
$res = `$pros`;
is($?, 0) or ASTU_Wait($res);
isnt(-d 't/logs/dprof', undef) or ASTU_Wait(read_file('t/conf/httpd.conf'));

my @outs = `find t/logs/dprof -type f`;
isnt(@outs, 0);

my $dres = `dprofpp $outs[0] 2>&1`;
is($?, 0) or ASTU_Wait($dres);
like($dres, qr/Total Elapsed Time/);

`rm -rf t/logs/dprof`;

my $hiddens = join("\n", map { "<input type=\"hidden\" name=\"n$_\""
	. " value=\"v$_\" />" } (1 .. 100));
write_file("templates/index.tt", <<ENDS);
<html>                                            
<body>
[% form %]
First: [% first %] <br />
<input type="submit" />
$hiddens
</form>
</body>
</html>
ENDS

write_file('t/dual/040_prof.t', <<'ENDS');
use strict;
use warnings FATAL => 'all';
use File::Slurp;

use Test::More tests => 3;

BEGIN { use_ok('T::Test'); };

my $t = T::Test->new;
$t->ok_ht_index_r(make_url => 1, param => { HT_SEALED_first => 12 }
		, ht => { HT_SEALED_first => 12 });
$t->ht_index_u;
is($t->mech->status, 200);
ENDS

$pros = 'APACHE_SWIT_PROFILE=1 make test_apache '
		. 'APACHE_TEST_FILES=t/dual/040_prof.t 2>&1';
$res = `$pros`;
is($?, 0) or ASTU_Wait($res);
isnt(-d 't/logs/dprof', undef) or ASTU_Wait(read_file('t/conf/httpd.conf'));

@outs = `find t/logs/dprof -type f`;
isnt(@outs, 0);

$dres = "";
$dres .= `dprofpp $_ 2>&1` for @outs;
is($?, 0) or ASTU_Wait($dres);
like($dres, qr/Total Elapsed Time/);

# number of calls to param should be low
unlike($dres, qr/\d\d\s+[\d\.]+\s+[\d\.]+\s+\S+param/);

chdir '/';
