use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Scaffold::ListTemplate;
use base qw(Apache::SWIT::Maker::Skeleton::HT::Template
		Apache::SWIT::Maker::Skeleton::Scaffold);

sub template { return <<'ENDS'; }
<html>
<body>
[% form %]
[% <% list_name_v %>_table %]
</form>
<br />
<a href="../form/r">Add entries</a>
</body>
</html>
ENDS

1;
