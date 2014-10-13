use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Object/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

subtest "Equilateral triangle in centre" => sub {
    # radius of filled in circle is r = a*sqrt(3)/6, where a is the side lenth
    my $r = sqrt(3);
    my $a = $r*6/sqrt(3);
    my $h = $a*sqrt(3)/2;
    my $t = Object->new(
        vertices => [
            Vertex->new([-$a/2, $h , 0]),
            Vertex->new([ $a/2, $h , 0]),
            Vertex->new([    0, -$h, 0]),
        ],
        indices => [ 0, 1, 2],
        normals => [ # does not matter
            Vector->new([0, 0, 1]),
            Vector->new([0, 1, 0]),
            Vector->new([1, 0, 0]),
        ],
    );
    ok $t;
    is $t->center, Vertex->new([0, 0, 0]);
};

done_testing;
