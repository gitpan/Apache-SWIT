use strict;
use warnings FATAL => 'all';

package T::Session;
use base 'Apache::SWIT::Session';

__PACKAGE__->add_var('persbox');

sub cookie_name { return 'foo' }
sub sessions_dir { return '/tmp/apache_swit_sessions'; }

1;
