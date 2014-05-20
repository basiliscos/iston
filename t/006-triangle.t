use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Triangle/;
use aliased qw/Iston::Vertex/;

subtest 'subdivision' => sub {
    my ($s1, $s2, $s3) = (
        Vertex->new([0, 0, 0]),
        Vertex->new([0, 2, 0]),
        Vertex->new([2, 0, 0]),
    );
    my $source = Triangle->new(
        vertices => [$s1, $s2, $s3],
    );
    my $triangles = $source->subdivide;
    is scalar(@$triangles), 4;

    my ($n1, $n2, $n3) = (
        Vertex->new([1, 1, 0]),
        Vertex->new([1, 0, 0]),
        Vertex->new([0, 1, 0]),
    );
    is $triangles->[0]->vertices->[0], $s1;
    is $triangles->[0]->vertices->[1], $n2;
    is $triangles->[0]->vertices->[2], $n3;

    is $triangles->[1]->vertices->[0], $s2;
    is $triangles->[1]->vertices->[1], $n1;
    is $triangles->[1]->vertices->[2], $n3;

    is $triangles->[2]->vertices->[0], $s3;
    is $triangles->[2]->vertices->[1], $n1;
    is $triangles->[2]->vertices->[2], $n2;

    is $triangles->[3]->vertices->[0], $n1;
    is $triangles->[3]->vertices->[1], $n2;
    is $triangles->[3]->vertices->[2], $n3;
};

done_testing;
