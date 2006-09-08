use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Skeleton::Scaffold::InfoTemplate;
use base qw(Apache::SWIT::Maker::Skeleton::HT::Template
		Apache::SWIT::Maker::Skeleton::Scaffold);

sub template { return <<'ENDS'; }
<html>
<body>
[% form %]<% FOREACH fields_v %>
<% title %>: [% <% field %> %] <br /><% END %>
</form>
[% edit_link %]
</body>
</html>
ENDS

1;
