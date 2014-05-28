use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Object/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

subtest "1 triangle to mesh" => sub {
    my $t = Object->new(
        normals  => [
            Vector->new([0, 0, 1]),
            Vector->new([1, 0, 0]),
            Vector->new([0, 1, 0]),
        ],
        vertices => [
            Vertex->new([0, 0, 0]),
            Vertex->new([1, 1, 1]),
            Vertex->new([2, 2, 2]),
        ],
        indices => [ 0, 1, 2 ],
    );
    $t->mode('mesh');

    is scalar(@{ $t->indices }), 6;
    is_deeply $t->indices, [0, 1, 1, 2, 2, 0],
        "indices transformed";

    $t->mode('normal');
    is scalar(@{ $t->indices }), 3;
    is_deeply $t->indices, [0, 1, 2],
        "indices un-transformed";

};

subtest "2 triangles to mesh" => sub {
    my $t = Object->new(
        vertices => [
            Vertex->new([0, 0, 0]),
            Vertex->new([1, 1, 1]),
            Vertex->new([2, 2, 2]),
            Vertex->new([3, 3, 3]),
            Vertex->new([4, 4, 4]),
            Vertex->new([5, 5, 5]),
        ],
        normals  => [
            Vector->new([0, 0, 1]),
            Vector->new([1, 0, 0]),
            Vector->new([0, 1, 0]),
            Vector->new([3, 3, 3]),
            Vector->new([4, 4, 4]),
            Vector->new([5, 5, 5]),
        ],
        indices => [
            0, 1, 2,
            3, 4, 5,
        ],
    );
    $t->mode('mesh');

    is scalar(@{ $t->indices }), 12;
    is_deeply $t->indices, [
        0, 1, 1, 2, 2, 0,
        3, 4, 4, 5, 5, 3,
    ],  "indices transformed";

    $t->mode('normal');
    is scalar(@{ $t->indices }), 6;
    is_deeply $t->indices,
        [ 0, 1, 2,
          3, 4, 5,],
        "indices un-transformed";

};

done_testing;
