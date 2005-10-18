use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker;
use base 'Class::Accessor';
use File::Path;
use File::Basename qw(dirname);
use YAML;
use File::Copy;
use Cwd qw(abs_path);

__PACKAGE__->mk_accessors(qw(root_class root_location app_name root_var_name
			session_class));

sub rf {
	my $file = shift;
	open(my $fh, $file) or die "Unable to open Makefile";
	my $mf_str = join('', <$fh>);
	close $fh;
	return $mf_str;
}

sub wf {
	my ($file, $content) = @_;
	open(my $fh, ">$file") or die "Unable to open $file";
	print $fh $content;
	close $fh;
}

sub wf_path {
	my ($f, $str) = @_;
	mkpath(dirname($f));
	wf($f, $str);
}

sub new {
	my $self = shift->SUPER::new(@_);
	unless ($self->root_class) {
		my $mf_str = rf('Makefile.PL');
		my ($root_class) = ($mf_str =~ /NAME[^\n\']+\'([^\']+)/);
		die "Unable to get root_class from $mf_str" unless $root_class;
		$self->root_class($root_class);
	}
	unless ($self->session_class) {
		$self->session_class($self->root_class . "::Session");
	}
	unless ($self->root_location) {
		my $rl = lc("/" . $self->root_class);
		$rl =~ s/::/\//g;
		$self->root_location($rl);
	}
	unless($self->app_name) {
		my $app_name = $self->root_location;
		$app_name =~ s/\//-/g;
		$app_name =~ s/^-//;
		$self->app_name($app_name);
	}
	unless($self->root_var_name) {
		my $rvn = uc($self->root_class) . "_ROOT";
		$rvn =~ s/::/_/g;
		$self->root_var_name($rvn);
	}
	return $self;
}

sub write_swit_yaml {
	my $self = shift;
	wf_path('conf/swit.yaml', sprintf(<<ENDM
root_class: %s
root_location: "%s"
session_class: %s
pages: {}
ENDM
		, $self->root_class, $self->root_location, $self->session_class));
}

sub write_makefile_pl {
	my $self = shift;
	my $app_name = $self->app_name;
	my $mf_str = rf('Makefile.PL');

	wf('Makefile.PL', <<ENDM);
package MY;

$mf_str

sub postamble { return q{
config :: t/conf/httpd.conf conf/httpd.conf
	\$(NOECHO) \$(NOOP)
			
t/conf/httpd.conf :: t/conf/extra.conf.in
	PERL_DL_NONLAZY=1 \$(FULLPERLRUN) t/apache_test.pl -config

conf/httpd.conf :: conf/swit.yaml conf/httpd.conf.in
	PERL_DL_NONLAZY=1 \$(FULLPERLRUN) -MApache::SWIT::Maker -e 'Apache::SWIT::Maker->regenerate_httpd_conf'

test :: test_apache

APACHE_TEST_FILES = t/dual/*.t

test_apache :: pure_all
	\$(RM_F) t/logs/access_log  t/logs/error_log
	PERL_DL_NONLAZY=1 \$(FULLPERLRUN) t/apache_test.pl \$(APACHE_TEST_FILES)

realclean ::
	\$(RM_RF) t/htdocs t/logs
	\$(RM_F) t/conf/apache_test_config.pm  t/conf/modperl_inc.pl
	\$(RM_F) t/conf/extra.conf t/conf/httpd.conf t/conf/modperl_startup.pl
	\$(RM_F) conf/httpd.conf t/conf/my.conf
}}

sub test {
	my \$res = shift()->SUPER::test(\@_);
	\$res =~ s/(TEST_FILES[^\\n]+)/\$1 t\\/dual\\/\\*\\.t/;
	return \$res;
}

sub install {
	return <<ENDS;
install :: all 
	mkdir -p \\\$(SITEPREFIX)/share/$app_name/conf
	cp -a \\\$(INST_LIB) \\\$(SITEPREFIX)/share/$app_name
	perl -p -e \\"s#\\\\\\\@ServerRoot\\\\@#\\\$(SITEPREFIX)/share/$app_name#g\\" < conf/httpd.conf > \\\$(SITEPREFIX)/share/$app_name/conf/httpd.conf
	cp conf/startup.pl \\\$(SITEPREFIX)/share/$app_name/conf
	cp -a templates \\\$(SITEPREFIX)/share/$app_name
ENDS
}
ENDM
}

sub write_startup_pl {
	my $self = shift;
	wf('conf/startup.pl', sprintf(<<ENDM
use strict;
use warnings FATAL => 'all';

push \@INC, \$ENV{%s} . "/lib";

1;
ENDM
		, $self->root_var_name));
	wf('>MANIFEST', "conf/startup.pl\n");
}

sub write_pm_file {
	my ($self, $module_class, $str) = @_;
	my $module_file = "lib/$module_class.pm";
	$module_file =~ s/::/\//g;
	wf_path($module_file, <<ENDM);
use strict;
use warnings FATAL => 'all';

package $module_class;
$str

1;
ENDM
	wf('>MANIFEST', "$module_file\n");
}

sub write_session_pm {
	my $self = shift;
	my $an = $self->app_name;
	my $sess_dir = "/tmp/$an\_sessions";
	$self->write_pm_file($self->session_class, <<ENDM);
use base 'Apache::SWIT::Session';

sub sessions_dir { return '$sess_dir'; }
sub cookie_name { return '$an'; }

mkdir __PACKAGE__->sessions_dir;
ENDM
}

sub write_initial_files {
	my $self = shift;
	wf('>MANIFEST', "\n");

	my $root_class = $self->root_class;
	$self->write_swit_yaml;
	$self->write_session_pm;
	my $root_location = $self->root_location;

	wf_path('t/conf/extra.conf.in', <<ENDM);
Include conf/my.conf
ENDM

	wf('conf/httpd.conf.in', sprintf(<<ENDM
PerlSetEnv %s \@ServerRoot\@
PerlRequire \@ServerRoot\@/conf/startup.pl
ENDM
		, $self->root_var_name));

	wf_path('t/dual/001_load.t', <<ENDM);
use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use Apache::SWIT::Test;

BEGIN { use_ok('$root_class\::Index'); }

Apache::SWIT::Test->make_aliases(index => '$root_class\::Index');
my \$t = Apache::SWIT::Test->new;
\$t->ok_ht_index_r(base_url => "$root_location/index/r", ht => { first => '' });
ENDM

	wf('t/apache_test.pl', <<ENDM);
use Apache::TestRunPerl;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

\$ENV{SWIT_HAS_APACHE} = 1;
push \@ARGV, '-top_dir', abs_path(dirname(\$0) . "/../");
Apache::TestRunPerl->new->run(\@ARGV);
ENDM

	$self->write_makefile_pl;

	wf('>MANIFEST', <<ENDM);

t/conf/extra.conf.in
t/apache_test.pl
t/dual/001_load.t
conf/swit.yaml
conf/httpd.conf.in
ENDM
	$self->write_startup_pl;
	$self->add_ht_page('Index');
}

sub add_page {
	my ($self, $page_class, %args) = @_;
	my $tree = YAML::LoadFile('conf/swit.yaml') or die "No conf/swit.yaml found";
	my $entry_point = lc($page_class);
	$entry_point =~ s/::/\//g;
	my $tt_file = "templates/$entry_point.tt";
	my $full_class = $tree->{root_class} . "::$page_class";
	$tree->{pages}->{$entry_point} = {
		class => $full_class,
		template => $tt_file,
		location => $tree->{root_location} . "/$entry_point",
	};
	YAML::DumpFile('conf/swit.yaml', $tree);

	wf_path($tt_file, <<ENDM);
<html>
<body>
<form>
</form>
</body>
</html>
ENDM
	$self->write_pm_file($full_class, <<ENDM);
use base qw(Apache::SWIT);

sub swit_render {
	my (\$class, \$req) = \@_;
	my \$res = {};
	return (\$req->dir_config('SWITRoot') . '$tt_file', \$res);
}
ENDM
	wf('>MANIFEST', <<ENDM);
$tt_file
ENDM
	return $tree->{pages}->{$entry_point};
}

sub add_ht_page {
	my $p = shift()->add_page(@_);
	my $module_file = "lib/" . $p->{class} . ".pm";
	$module_file =~ s/::/\//g;
	my $tt_file = $p->{template};
	my $loc = $p->{location};
	my $full_class = $p->{class};
	wf_path($module_file, <<ENDM);
use strict;
use warnings FATAL => 'all';

package $full_class\::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_value('first');

package $full_class;
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { return '$full_class\::Root'; }

sub ht_swit_render {
	my (\$class, \$r, \$root) = \@_;
	return (\$r->dir_config('SWITRoot') . '$tt_file', \$root);
}

sub ht_swit_update {
	my (\$class, \$r, \$root) = \@_;
	return "$loc/r";
}

1;
ENDM
}

sub regenerate_httpd_conf {
	my $tree = YAML::LoadFile('conf/swit.yaml') or die "No conf/swit.yaml found";
	copy('conf/httpd.conf.in', 'conf/httpd.conf');
	wf('>conf/httpd.conf', <<ENDS
PerlModule $tree->{session_class}
<Location $tree->{root_location}>
	PerlSetVar SWITRoot \@ServerRoot\@/
	PerlSetVar SWITSession $tree->{session_class}
</Location>
ENDS
			. join("\n", map { <<ENDS
<Location $_->{location}>
	SetHandler perl-script
	PerlHandler $_->{class}
</Location>
ENDS
		 } values %{ $tree->{pages} }));
	my $c = rf('conf/httpd.conf');
	my $ap = abs_path('.');
	$c =~ s/\@ServerRoot\@/$ap/g;
	wf('t/conf/my.conf', $c);
}

sub remove_page {
	my ($class, $page) = @_;
	my $tree = YAML::LoadFile('conf/swit.yaml') or die "No conf/swit.yaml found";
	my $ep = lc($page);
	$ep =~ s/::/\//g;
	my $p = delete $tree->{pages}->{$ep} or die "Unable to find $page";
	my $module_file = "lib/" . $p->{class} . ".pm";
	$module_file =~ s/::/\//g;
	unlink($module_file);
	unlink($p->{template});
	open(my $fh, 'MANIFEST');
	my @lines = grep { !(/$module_file/ || /$p->{template}/) } <$fh>;
	close $fh;
	wf('MANIFEST', join("", @lines));
	YAML::DumpFile('conf/swit.yaml', $tree);
}

1;
