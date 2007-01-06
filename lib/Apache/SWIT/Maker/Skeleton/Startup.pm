use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Startup;
use base 'Apache::SWIT::Maker::Skeleton';

sub output_file { return 'conf/startup.pl'; }

sub template { return <<'ENDM'; }
use strict;
use warnings FATAL => 'all';

use HTML::Tested::Seal;
use File::Slurp;
use File::Basename qw(dirname);
use HTML::Tested qw(HT HTV);
use Apache::SWIT::DB::Connection;

HTML::Tested::Seal->instance(read_file(dirname($0) . '/seal.key'));

1;
ENDM

1;
