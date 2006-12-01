use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::FileWriterData;
use base 'Apache::SWIT::Maker::FileWriter';
use Apache::SWIT::Maker::Config;

__PACKAGE__->add_file({ name => 'scripts/swit_app.pl'
		, manifest => 1 }, <<'EM');
#!/usr/bin/perl -w
use strict;
use [% class %];
my $f = shift(@ARGV);
[% class %]->new->$f(@ARGV);
EM

__PACKAGE__->add_file({ name => 'tt_file', manifest => 1
	, tmpl_options => { START_TAG => '<%', END_TAG => '%>' } }, <<'EM');
<html>
<body>
[% form %]
<% content %>
</form>
</body>
</html>
EM

__PACKAGE__->add_file({ name => 't/direct_test.pl', manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';
use Test::Harness;
use T::TempDB;

runtests(@ARGV);
EM

__PACKAGE__->add_file({ name => 'db_pm', manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% class %];
use base '[% root %]::DB::Base';

__PACKAGE__->set_up_table('[% table %]', { ColumnGroup => 'Essential' });

1;
EM

__PACKAGE__->add_file({ name => 't/T/Test.pm', overwrite => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package T::Test;
use base 'Apache::SWIT::Test';
use [% session_class %];

__PACKAGE__->root_location('[% root_location %]');
__PACKAGE__->make_aliases(
[% aliases %]
);

sub new {
	my ($class, $args) = @_;
	$args->{session_class} = '[% httpd_session_class %]'
		unless exists($args->{session_class});
	return $class->SUPER::new($args);
}

1;
EM

__PACKAGE__->add_file({ name => 'test', manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

use Test::More tests => [% plan %];

BEGIN { [% FOREACH use_oks %]
	use_ok('[% module %]');[% END %]
};

[% content %]
EM

__PACKAGE__->add_file({ name => 'db_base_pm', manifest => 1 }, <<'EM');
use base 'Class::DBI::Pg';
use [% connection %];

$Class::DBI::Weaken_Is_Available = 0;
sub db_Main {
	return [% connection %]->instance->db_handle;
}
EM

__PACKAGE__->add_file({ name => 'conf/startup.pl', manifest => 1 }, <<'ES');
use strict;
use warnings FATAL => 'all';

use HTML::Tested::Seal;
use File::Slurp;
use File::Basename qw(dirname);

HTML::Tested::Seal->instance(read_file(dirname($0) . '/seal.key'));

1;
ES

__PACKAGE__->add_file({ name => 'conf/makefile_rules.yaml', manifest => 1 }
		, <<'EM');
- targets: [ config ]
  dependencies: 
    - t/conf/httpd.conf
    - blib/conf/httpd.conf
    - blib/conf/seal.key
  actions:
    - $(NOECHO) $(NOOP)
- targets: [ t/conf/httpd.conf ]
  dependencies: 
    - t/conf/extra.conf.in
  actions:
    - PERL_DL_NONLAZY=1 $(FULLPERLRUN) t/apache_test_run.pl -config
- targets: [ blib/conf/seal.key ]
  dependencies:
    - Makefile
  actions:
    - ./scripts/swit_app.pl regenerate_seal_key
- targets: [ blib/conf/httpd.conf ]
  dependencies:
    - conf/swit.yaml
    - conf/httpd.conf.in
  actions:
    - ./scripts/swit_app.pl regenerate_httpd_conf
EM

sub add_root_class_file {
	my ($class, $opts, $content) = @_;
	my $n = $opts->{name};
	goto OUT unless ($opts->{name} =~ s/\%s[\/\.]//);
	$opts->{path} = sub {
		my $o = shift;
		my $rc = $o->{new_root} || Apache::SWIT::Maker::Config
						->instance->root_class;
		$o->{vars}->{root_class} = $rc;
		$rc =~ s/::/\//g;
		return sprintf($n, $rc);
	};
OUT:
	$class->add_file($opts, $content);
}

__PACKAGE__->add_root_class_file({ overwrite => 1,
		name => 'blib/lib/%s/InstallationContent.pm' }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% root_class %]::InstallationContent;

[% FOREACH dumps %]
sub this_subsystem_[% name %] {
	my [% dump %];
	return $VAR1;
}
[% END %]

1;
EM

__PACKAGE__->add_root_class_file({ name => 'lib/%s.pm'
		, manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% root_class %];
[% content %]
1;
EM

1;
