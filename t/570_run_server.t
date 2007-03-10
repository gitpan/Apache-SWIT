use strict;
use warnings FATAL => 'all';

use Test::More tests => 12;
use Test::TempDatabase;
Test::TempDatabase->become_postgres_user;

use LWP::UserAgent;
use IPC::Run qw( start pump finish timeout ) ;

BEGIN { use_ok('Apache::SWIT::Maker');
	use_ok('Apache::SWIT::Test::ModuleTester');
}

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;
$mt->make_swit_project;
ok(-f 'LICENSE');
`perl Makefile.PL && make 2>&1`;


my @cmd = ("./scripts/swit_app.pl", "run_server"); 
my ($in, $out, $err);
my $t = timeout(30);

my $h = start(\@cmd, \$in, \$out, \$err, $t);
eval { pump $h until $err =~ /Press Enter to finish \.\.\./; };
if ($@) {
	diag("Error in pumping: $@\n$err");
	exit 1;
}

my ($host) = ($out =~ /server ([^\n]+) started/);
like($err, qr/Press Enter to finish \.\.\./);
isnt($host, undef) or $host = '';

my $ua = LWP::UserAgent->new;
my $cont = $ua->get("http://$host/ttt/index/r")->content;
like($cont, qr/first/);
like($err, qr#http://$host#);

unlike($out, qr/Leaving/);
$in .= "\n";
pump $h;

while(pump $h) {}
like($out, qr/Leaving/);
finish $h or die "cmd returned $?" ;

($in, $out, $err) = ();
my $help = `./scripts/swit_app.pl 2>&1`;
like($help, qr/run_server.*host.*port/);

system("make realclean 2>/dev/null 1>/dev/null");
push @cmd, "goo.ga:11111";

$h = start(\@cmd, \$in, \$out, \$err, $t);
pump $h until $err =~ /Press Enter to finish \.\.\./;
($host) = ($out =~ /server ([^\n]+) started/);
like($err, qr/Press Enter to finish \.\.\./);
is($host, "goo.ga:11111");
finish $h or die "cmd returned $?" ;

chdir '/';

