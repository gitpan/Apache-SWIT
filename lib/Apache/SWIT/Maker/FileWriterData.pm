use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::FileWriterData;
use base 'Apache::SWIT::Maker::FileWriter';

__PACKAGE__->add_file({ name => 'scripts/swit_app.pl'
		, manifest => 1 }, <<'EM');
#!/usr/bin/perl -w
use strict;
use [% class %];
my $f = shift(@ARGV);
[% class %]->new->$f(@ARGV);
EM

1;
