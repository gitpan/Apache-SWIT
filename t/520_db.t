use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::Maker'); }

delete $ENV{TEST_FILES};
delete $ENV{MAKEFLAGS};
delete $ENV{MAKEOVERRIDES};

my $td = tempdir('/tmp/swit_db_XXXXXX', CLEANUP => 1);
chdir $td;
`modulemaker -I -n TTT`;
ok(-f './TTT/LICENSE');
chdir 'TTT';

Apache::SWIT::Maker->new->write_initial_files();
ok(-f 'lib/TTT/DB/Schema.pm');
ok(-f 't/test_db.pl');

sub replace_in_file {
	my ($f, $from, $to) = @_;
	open(my $fh, $f) or die "Unable to open $f\n";
	my $str = join('', <$fh>);
	close $fh;
	$str =~ s/$from/$to/g;
	open($fh, ">$f") or die "Unable to open $f\n";
	print $fh $str;
	close $fh;
}

replace_in_file('t/dual/001_load.t', '2', '3');
replace_in_file('t/dual/001_load.t', '\); \}', 
	");\n\tuse_ok('TTT::DB::Connection'); }");
replace_in_file('lib/TTT/DB/Schema.pm', 'shift;', <<ENDM);
shift;
	\\\$dbh->do("create table ttt_table (a text)");
ENDM
replace_in_file('t/dual/001_load.t', "\\}\\\n", <<ENDM);
}
TTT::DB::Connection->instance->db_handle->do(
		"insert into ttt_table values ('aaa')");
ENDM

replace_in_file('t/dual/001_load.t', "''", <<ENDM);
'aaa'
ENDM

replace_in_file('lib/TTT/Index.pm', "return \\(", <<ENDM);
use TTT::DB::Connection;
my \$arr = TTT::DB::Connection->instance->db_handle->selectcol_arrayref(
		"select a from ttt_table");
\$root->first(\$arr->[0]);
return (
ENDM

my $tres = join('', `perl Makefile.PL && make disttest 2>&1`);
like($tres, qr/success/);
unlike($tres, qr/Fail/);

#diag($td);
#readline(\*STDIN);
chdir '/'
