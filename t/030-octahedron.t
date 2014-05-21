use 5.12.0;

use Test::More;
use Test::Warnings;
use List::MoreUtils qw/any first_index/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Object::Octahedron/;

subtest "simple creation" => sub {
    my $o = Octahedron->new;
    ok $o, "octahedron instance successfully has been created";
    my $top = Vertex->new([0, 1, 0]);
    my $bottom = Vertex->new([0, -1, 0]);
    my $top_idx = first_index {$top eq $_ } @{ $o->vertices };
    is $o->normals->[$top_idx], Vector->new([0, 1, 0]);
    my $bottom_idx = first_index {$bottom eq $_} @{ $o->vertices };
    is $o->normals->[$bottom_idx], Vector->new([0, -1, 0]);
    $o->subdivide;
    pass "created";
};

subtest "many subdivisions" => sub {
    my $o = Octahedron->new;
    my $v_count = scalar(@{$o->vertices});
    my $i_count = scalar(@{$o->indices});
    for my $i (1 .. 1) {
        $o->subdivide;
        is scalar(@{$o->vertices}), $v_count * 3,
            "vertices count match";
        is scalar(@{$o->indices}), $i_count * 4,
            "indices count match";
        $v_count = scalar(@{$o->vertices});
        $i_count = scalar(@{$o->indices});
        for (@{$o->indices}) {
            ok $_ < $v_count, "index $_ less then vertices count $v_count";
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
