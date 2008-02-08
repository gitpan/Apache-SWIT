use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use Test::TempDatabase;
use File::Slurp;
use Apache::SWIT::Test::Utils;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');

$mt->replace_in_file('lib/' . $mt->module_dir . "/Session.pm", '1', <<'ENDM');
sub access_handler {
	my ($class, $r) = @_;
	my $res = $class->SUPER::access_handler($r);
	return ($r->pnotes('SWITSession')->get_deny && $r->uri !~ qr/index/)
			? Apache2::Const::FORBIDDEN() : $res;
}

__PACKAGE__->add_var('deny');

1;
ENDM

$mt->replace_in_file('lib/TTT/UI/Index.pm', "return \\\"", <<'ENDM');
$r->pnotes('SWITSession')->set_deny(1);
return "
ENDM

$mt->replace_in_file('t/dual/001_load.t', '=> 11', '=> 13');
append_file('t/dual/001_load.t', <<'ENDM');
$t->ok_ht_index_r(make_url => 1, ht => { first => '' });
$t->ht_index_u(ht => {});
$t->ok_get('www/main.css', 403);
ENDM
my $res = `perl Makefile.PL && make test_dual 2>&1`;
is($?, 0) or ASTU_Wait($res);
like($res, qr/success/) or ASTU_Wait();

