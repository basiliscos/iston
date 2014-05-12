use 5.12.0;

use Test::More;
use Test::Warnings;
use t::IstonTest qw/vector_eq/;

use aliased qw/Iston::Object/;

subtest "Equilateral triangle in centre" => sub {
    # radius of filled in circle is r = a*sqrt(3)/6, where a is the side lenth
    my $r = sqrt(3);
    my $a = $r*6/sqrt(3);
    my $h = $a*sqrt(3)/2;
    my $t = Object->new(
        vertices => [
            -$a/2, $h , 0,
             $a/2, $h , 0,
                0, -$h, 0,
        ],
        indices => [ 0, 1, 2],
        normals => [ # does not matter
            0, 0, 1,
            0, 1, 0,
            1, 0, 0,
        ],
    );
    ok $t;
    vector_eq($t->center, [0, 0, 0]);
};

subtest "Object transtation" => sub {
    my $t = Object->new(
        vertices => [
            1, 0, 0,
            0, 2, 0,
            0, 0, 3,
        ],
        indices => [ 0, 1, 2],
        normals => [ # does not matter
            0, 0, 1,
            0, 1, 0,
            1, 0, 0,
        ],
    );
    my ($mins, $maxs) = $t->boudaries;
    vector_eq($mins, [0,0,0]);
    vector_eq($maxs, [1,2,3]);

    my $center = $t->center;
    my $to_center = [ map { $_ * -1 } @$center ];
    $t->translate($to_center);
    vector_eq($t->center, [0, 0, 0]);

    $t->translate([1.5, 2, 2.5]);
    vector_eq([2, 1, 1], [ @{ $t->vertices} [0 .. 2] ]);
    vector_eq([1, 3, 1], [ @{ $t->vertices} [3 .. 5] ]);
    vector_eq([1, 1, 4], [ @{ $t->vertices} [6 .. 8] ]);

    $center = $t->center;
    $to_center = [ map { $_ * -1 } @$center ];
    $t->translate($to_center);
    vector_eq($t->center, [0, 0, 0]);
};

done_testing;
