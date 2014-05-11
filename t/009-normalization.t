use 5.12.0;

use Function::Parameters qw(:strict);
use Test::More;
use Test::Warnings;

use Iston::Utils qw/normalize/;

my $_ERROR = 0.00001;

fun _eq($got, $expected) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is scalar(@$expected), scalar(@$got), "sizes match";
    for my $i (0 .. @$expected-1) {
        my ($e, $g) = ($expected->[$i], $got->[$i]);
        ok abs($g - $e ) < $_ERROR,
            "component $i matches ($g == $e)";
    }
}

subtest "normalize normalized" => sub {
    my $v = [0, 0, 1];
    my $n = normalize($v);
    _eq($n, $v);
};

subtest "normalize simple" => sub {
    my $v = [0, 0, 4];
    my $n = normalize($v);
    _eq($n, [0, 0, 1]);
};


done_testing;
