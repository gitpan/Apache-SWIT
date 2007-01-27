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
use HTML::Tested::JavaScript qw(HTJ);
use Apache::SWIT::DB::Connection;
use HTML::Tested::List;

eval "use " . HTV() . "::$_" for qw(Marked Form Hidden Submit EditBox Link
					Upload);

HTML::Tested::Seal->instance(read_file(dirname($0) . '/seal.key'));

1;
ENDM

1;
