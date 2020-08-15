use 5.12.0;

use Test::More;
use Test::Warnings;
use List::MoreUtils qw/any first_index/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Object::HTM/;

subtest "simple creation" => sub {
    my $o = HTM->new;
    ok $o, "octahedron instance successfully has been created";
    is scalar( @{$o->triangles} ), 8, "initally we have 8 triangles";
    my $top = Vertex->new(values => [0, 1, 0]);
    my $bottom = Vertex->new(values => [0, -1, 0]);
    my $top_idx = first_index {$top eq $_ } @{ $o->triangles->[0]->vertices };
    is $o->triangles->[0]->normals->[$top_idx], Vector->new(values => [0, 1, 0]),
        "normal for top of octachedron has top direction";
    my $bottom_idx = first_index {$bottom eq $_} @{ $o->triangles->[-1]->vertices };
    is $o->triangles->[-1]->normals->[$bottom_idx], Vector->new(values => [0, -1, 0]),
        "normal for bottom of octachedron has bottom direction";
    $o->level($o->level+1);
    is scalar( @{$o->triangles} ), 8*4, "correct number of triangles after subdivision";
    
    subtest "triangle colors" => sub {
        $o->triangles->[0]->{payload}->{time_share} = 0.9;
        $o->triangles->[1]->{payload}->{time_share} = 0.1;
        my $colors = $o->triangle_colors;
        is_deeply $colors, [
            [229, 229, 0, 229],
            [25, 25, 0, 25],
            (([0, 0, 0, 0]) x 30),
        ];
    };
};

subtest "check triangles count directly at 4-th level" => sub {
    my $o = HTM->new;
    is $o->level, 0;
    my $i_count = scalar(@{$o->triangles});
    is $i_count, 8, "level 0 right";

    $o->level(4);
    $i_count = scalar(@{$o->triangles});
    is $i_count, 8*4**4, "level 4 is right";
    is $o->triangles->[-1]->path, "path[7:3:3:3:3]",
        "path of the last triangle is corrrect";

    $o->level(0);
    my $i_count = scalar(@{$o->triangles});
    is $i_count, 8, "level 0 right (again)";
};

subtest "sequential subdivisions" => sub {
    my $o = HTM->new;
    for my $i (1 .. 3) {
        $o->level($i);
        pass "subdivision $i passed";
    };
};

done_testing;
