package Iston::Utils;

use 5.12.0;

use Function::Parameters qw(:strict);
use List::Util qw/reduce/;

use parent qw/Exporter/;

our @EXPORT_OK = qw/normalize/;

fun normalize($vector){
    my($x,$y,$z) = (0,1,2);
    my $length =
        reduce { $a + $b }
        map { $_ * $_ }
        map {$vector->[$_] }
        ($x, $y, $z);
    $length = sqrt($length);
    my @r =
        map { sprintf ('%f', $_) }
        map { $_ / $length  }
        map {$vector->[$_] }
        ($x, $y, $z);
    return \@r;
}

1;
