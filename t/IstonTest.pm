package t::IstonTest;

use 5.12.0;

use Function::Parameters qw(:strict);
use Test::More;
use Test::Warnings;
use Test::Builder;

use parent qw/Exporter/;

our @EXPORT_OK = qw/vector_eq/;

my $_ERROR = 0.00001;

fun vector_eq($got, $expected) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is scalar(@$expected), scalar(@$got), "sizes match";
    for my $i (0 .. @$expected-1) {
        my ($e, $g) = ($expected->[$i], $got->[$i]);
        ok abs($g - $e ) < $_ERROR,
            "component $i matches ($g == $e)";
    }
}

1;
