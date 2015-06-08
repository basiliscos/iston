use 5.16.0;
use utf8;

use Path::Tiny;
use Test::More;
use Test::Warnings;

use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Zone/;


subtest "polar vercices" => sub {
    my $z = Zone->new(
        xz     => 0,
        yz     => 0,
        spread => 90,
    );

    my ($c1, $v1, $v2) = $z->sphere_points(0);
    is $c1, Vertex->new(values => [0,  0,   1]), "center unmoved";
    is $v1, Vertex->new(values => [0,  1.0, 0.0]), "positive vertex is north pole";
    is $v2, Vertex->new(values => [0, -1.0, 0.0]), "negative vertex is south pole";

    ($c1, $v1, $v2) = $z->sphere_points(90);
    is $c1, Vertex->new(values => [0,  0,   1]), "center unmoved";
    is $v1, Vertex->new(values => [-1.0, 0.0, 0.0]), "positive vertex is west pole";
    is $v2, Vertex->new(values => [1.0,  -0.0, 0.0]), "negative vertex is east pole";
};

done_testing;
