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
    my $top = Vertex->new([0, 1, 0]);
    my $bottom = Vertex->new([0, -1, 0]);
    my $top_idx = first_index {$top eq $_ } @{ $o->vertices };
    is $o->normals->[$top_idx], Vector->new([0, 1, 0]);
    my $bottom_idx = first_index {$bottom eq $_} @{ $o->vertices };
    is $o->normals->[$bottom_idx], Vector->new([0, -1, 0]);
    $o->level($o->level+1);
    pass "created";
};

subtest "check indices directly at 4-th level" => sub {
    my $o = HTM->new;
    is $o->level, 0;
    my $i_count = scalar(@{$o->indices});
    is $i_count, 8*3;

    $o->level(4);
    $i_count = scalar(@{$o->indices});
    is $i_count, (8*3)*4**4;

    $o->level(0);
    my $i_count = scalar(@{$o->indices});
    is $i_count, 8*3;
};

subtest "sequential subdivisions" => sub {
    my $o = HTM->new;
    my $v_count = scalar(@{$o->vertices});
    my $i_count = scalar(@{$o->indices});
    my $sum = sub {
        my $to = shift;
        my $r = (((1 + $to)))*$to/2;
        $r;
    };
    for my $i (1 .. 3) {
        $o->level($i);
        my $layers = 2**$i;
        my $vertices_on_side_bottom = 1+$layers;
        my $vertices_per_side = $sum->($vertices_on_side_bottom);
        my $vertices_per_pyramid = $vertices_per_side*4 - $vertices_on_side_bottom*4 + 1;
        my $vertices = $vertices_per_pyramid*2 - $vertices_on_side_bottom*4 + 4;
        is scalar(@{$o->vertices}), $vertices;
            "vertices count match";
        is scalar(@{$o->indices}), $i_count * 4,
            "indices count match";
        $v_count = scalar(@{$o->vertices});
        $i_count = scalar(@{$o->indices});
        for (@{$o->indices}) {
            ok $_ < $v_count, "index $_ less then vertices count $v_count";
            ok $_ >= 0, "index isn't negative";
        }
        for my $i (0 .. @{$o->vertices} -1) {
            my $v = $o->vertices->[$i];
            my $exists = any { $_ eq $i } @{$o->indices};
            ok $exists, "$v exists among indices";
        }
        pass "subdivision $i passed";
    };
};

done_testing;
