package Iston::Utils;

use 5.12.0;

use Function::Parameters qw(:strict);
use List::Util qw/reduce/;

use parent qw/Exporter/;

our @EXPORT_OK = qw/normalize vector_length/;

fun vector_length($vector){
    return sqrt(
        reduce  { $a + $b }
            map { $_ * $_ }
            map {$vector->[$_] }
            (0 .. 2)
    );
}

fun normalize($vector){
    my $length = vector_length($vector);
    return $vector if($length == 0);
    my @r =
        map { sprintf ('%f', $_) }
        map { $_ / $length  }
        map {$vector->[$_] }
        (0 .. 2);
    return \@r;
}

1;
