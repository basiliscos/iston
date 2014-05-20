use 5.12.0;

use Test::More;
use Test::Warnings;
use List::MoreUtils qw/any/;

use aliased qw/Iston::Object::Octahedron/;

subtest "simple creation" => sub {
    my $o = Octahedron->new;
    ok $o, "octahedron instance successfully has been created";
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
