use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::Vertex/;

subtest "precision_equality" => sub{
    my $v1 = Vertex->new(values => [
        '-0.288675134594813',
         '0.408248290463863',
         '0.866025403784439',
    ]);
    my $v2 = Vertex->new(values => [
        '-0.288675134594813',
         '0.408248290463863',
         '0.866025403784438',
    ]);
    is $v1, $v2;
    ok $v1 == $v2, " == ";
    ok $v1 eq $v2, ' eq ';
};

done_testing;
