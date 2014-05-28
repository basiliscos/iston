use 5.12.0;

use Test::More;
use Test::Warnings;

use Iston::Vector qw/normal/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;


subtest 'addition' => sub {
    my $a = Vector->new([1,2,3]);
    my $b = Vector->new([0,4,5]);
    my $c = $a + $b;
    is $c, Vector->new([1,6,8]);
};

subtest "normalize normalized" => sub {
    my $v = Vector->new([0, 0, 1]);
    is $v->normalize, Vector->new([0, 0, 1]);
};

subtest "normalize simple" => sub {
    my $v = Vector->new([0, 0, 4]);
    is $v->normalize, Vector->new([0, 0, 1]);
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

done_testing;
