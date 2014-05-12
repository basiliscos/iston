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
    my $center = [ map{ $t->$_ } (qw/x y z/) ];
    vector_eq([0, 0, 0], $center);
};

done_testing;
