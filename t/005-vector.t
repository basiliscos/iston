use 5.12.0;

use Test::More;
use Test::Warnings;

use Iston::Vector qw/normal/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

subtest 'zero vector' => sub {
    my $a = Vector->new([0,0,0]);
    my $b = Vector->new([0,0,-0.00000000001]);
    ok $a->is_zero;
    ok $b->is_zero;
};

subtest 'addition' => sub {
    my $a = Vector->new([1,2,3]);
    my $b = Vector->new([0,4,5]);
    my $c = $a + $b;
    is $c, Vector->new([1,6,8]);
};

subtest 'substraction' => sub {
    my $a = Vector->new([1,2,3]);
    my $b = Vector->new([0,4,5]);
    my $c = $b - $a;
    is $c, Vector->new([-1,2,2]);
};

subtest "normalize normalized" => sub {
    my $v = Vector->new([0, 0, 1]);
    is $v->normalize, Vector->new([0, 0, 1]);
};

subtest "normalize simple" => sub {
    my $v = Vector->new([0, 0, 4]);
    is $v->normalize, Vector->new([0, 0, 1]);
    $v = Vector->new([0, 2, 4])->normalize;
    is $v, 'vector[0.0000, 0.4472, 0.8944]';
};

subtest "vertex on scalar multiplication" => sub {
    my $v = Vector->new([ 1, -2, 3]) * 1.5;
    is $v, Vector->new([1.5, -3, 4.5]);

    $v = 1.5 * Vector->new([ 1, -2, 3]);
    is $v, Vector->new([1.5, -3, 4.5]);
};

subtest "vertices multiplication" => sub {
    my ($a, $b) = (
        Vector->new([ 0.5, 0, 1.5]),
        Vector->new([-0.5, 0, 1.5]),
    );
    my $v = $a * $b;
    is $v, Vector->new([0, -1.5, 0]);
    $v = $b * $a;
    is $v, Vector->new([0, 1.5, 0]);
};

subtest 'scalar vertices multiplication' => sub {
    is Vector->new([-1, 0, 0])->scalar_multiplication(
        Vector->new([ 0, 1, 0])
    ), 0;
    is Vector->new([-1, 1, 0])->scalar_multiplication(
        Vector->new([ 1, 1, 0])
    ), 0;
    is Vector->new([-1, 1, 0])->scalar_multiplication(
        Vector->new([ -1, 2, 0])
    ), 3;
};

subtest "stringification/comparison" => sub{
    my $v1 = Vector->new([1,  0,  1])->normalize;
    my $v2 = Vector->new([1,  0,  1])->normalize;
    is $v1, $v2;
};

subtest "normal from vertices" => sub {
    my $v = normal(
        [
            Vertex->new([0, 0, -1]),
            Vertex->new([0.5, 0, 0.5]),
            Vertex->new([-0.5, 0, 0.5]),
        ],
        [0, 1, 2]
    );
    is $v, Vector->new([0, -1, 0]);

    $v = normal(
        [
            Vertex->new([0, 0, -1]),
            Vertex->new([0.5, 0, 0.5]),
            Vertex->new([-0.5, 0, 0.5]),
        ],
        [0, 2, 1]
    );
    is $v, Vector->new([0, 1, 0]);
};

subtest "angle with roundings" => sub {
    my $a = Vector->new([
        0.00242890552309209,
        1.49619899803e-17,
        0.0172825608175412
    ]);
    my $b = Vector->new([
        0.00242890552309215,
        -7.58941520739853e-19,
        0.0172825608175416,
    ]);
    my $angle = $a->angle_with($b);
    my $str = sprintf('%0.2f', $angle);
    ok $str;
};

done_testing;
