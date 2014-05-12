use 5.12.0;

use Test::More;
use Test::Warnings;
use Test::Builder;
use t::IstonTest qw/vector_eq/;

use Iston::Utils qw/normalize/;

my $_ERROR = 0.00001;

subtest "normalize normalized" => sub {
    my $v = [0, 0, 1];
    my $n = normalize($v);
    vector_eq($n, $v);
};

subtest "normalize simple" => sub {
    my $v = [0, 0, 4];
    my $n = normalize($v);
    vector_eq($n, [0, 0, 1]);
};

done_testing;
