use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::GeneratorBase;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(tree));

1;
