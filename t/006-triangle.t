use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Triangle/;
use aliased qw/Iston::TrianglePath/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

subtest 'subdivision' => sub {
    my ($s1, $s2, $s3) = (
        Vertex->new([0, 0, 0]),
        Vertex->new([0, 2, 0]),
        Vertex->new([2, 0, 0]),
    );
    my $source = Triangle->new(
        vertices => [$s1, $s2, $s3],
        path     => TrianglePath->new(0),
    );
    is $source->path, "path[0]";
    my $triangles = $source->subtriangles;
    is scalar(@$triangles), 4;

    my ($n1, $n2, $n3) = (
        Vertex->new([1, 1, 0]),
        Vertex->new([1, 0, 0]),
        Vertex->new([0, 1, 0]),
    );
    is $triangles->[0]->path, "path[0:0]";
    is $triangles->[0]->vertices->[0], $s1;
    is $triangles->[0]->vertices->[1], $n3;
    is $triangles->[0]->vertices->[2], $n2;

    is $triangles->[1]->path, "path[0:1]";
    is $triangles->[1]->vertices->[0], $s2;
    is $triangles->[1]->vertices->[1], $n1;
    is $triangles->[1]->vertices->[2], $n3;

    is $triangles->[2]->path, "path[0:2]";
    is $triangles->[2]->vertices->[0], $s3;
    is $triangles->[2]->vertices->[1], $n2;
    is $triangles->[2]->vertices->[2], $n1;

    is $triangles->[3]->path, "path[0:3]";
    is $triangles->[3]->vertices->[0], $n3;
    is $triangles->[3]->vertices->[1], $n1;
    is $triangles->[3]->vertices->[2], $n2;
};

subtest 'normals-of-triangle' => sub {
    my ($a, $b, $c) = (
        Vertex->new([0, 0, -1]),
        Vertex->new([0.5, 0, 0.5]),
        Vertex->new([-0.5, 0, 0.5]),
    );
    my $t1 = Triangle->new(
        vertices => [$a, $b, $c],
        path     => TrianglePath->new(0),
    );
    is $t1->normal, Vector->new([0, -1, 0]);

    my $t2 = Triangle->new(
        vertices => [$b, $a, $c],
        path     => TrianglePath->new(0),
    );
    is $t2->normal, Vector->new([0, 1, 0]);
};

subtest 'normals-of-subdivided-triangles' => sub {
    my ($a, $b, $c) = (
        Vertex->new([0, 0, -1]),
        Vertex->new([-0.5, 0, 0.5]),
        Vertex->new([0.5, 0, 0.5]),
    );
    my $t1 = Triangle->new(
        vertices => [$a, $b, $c],
        path     => TrianglePath->new(0),
    );
    my $n = $t1->normal;

    my $triangles = $t1->subtriangles;
    for (@$triangles) {
        is $_->normal, $n;
    }
};

subtest 'tesselation-of-subdivided-triangles' => sub {
    my ($a, $b, $c) = (
        Vertex->new([2, 0, 0]),
        Vertex->new([0, 2, 0]),
        Vertex->new([0, 0, 2]),
    );
    my $t_s = Triangle->new(
        vertices    => [$a, $b, $c],
        path        => TrianglePath->new(0),
        tesselation => 1);
    my $triangles = $t_s->subtriangles;
    for my $t (@$triangles) {
        ok $t->tesselation, "tesselation properry has been inherited";
        for my $vertex (@{$t->vertices}) {
            my $v = Vector->new($vertex);
            is $v->length, 2, "subdivided tesselated triangle has correct radius";
        }
    }
};

subtest 'intesection-of-sphere-radius-with-triangle' => sub {
    my $vertex_on_sphere = Vertex->new([0, 0, 2]);
    my $triangle = Triangle->new(
        vertices    => [
            Vertex->new([0,     0.5, 0.5]),
            Vertex->new([0.5,  -0.5, 0.5]),
            Vertex->new([-0.5, -0.5, 0.5]),
        ],
        path        => TrianglePath->new(0),
        tesselation => 0,
    );
    my $vertex_on_triangle = $triangle->intersects_with($vertex_on_sphere);
    is $vertex_on_triangle, Vertex->new([0, 0, 0.5]);
};

subtest 'no-intesection-of-sphere-radius-with-triangle' => sub {
    my $vertex_on_sphere = Vertex->new([0, 0, 2]);
    my $triangle = Triangle->new(
        vertices    => [
            Vertex->new([0,    0.5,  0.5]),
            Vertex->new([0.5,  0.5, -0.5]),
            Vertex->new([-0.5, 0.5, -0.5]),
        ],
        path        => TrianglePath->new(0),
        tesselation => 0,
    );
    my $vertex_on_triangle = $triangle->intersects_with($vertex_on_sphere);
    is $vertex_on_triangle, undef;
};

done_testing;
