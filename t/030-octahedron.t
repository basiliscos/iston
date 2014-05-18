use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Object::Octahedron/;

my $o = Octahedron->new;
ok $o, "octahedron instance successfully has been created";

done_testing;
