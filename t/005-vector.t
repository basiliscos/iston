use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Vector/;

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

done_testing;
