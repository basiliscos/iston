package Iston::Matrix;

use 5.16.0;

use parent qw/Math::MatrixReal/;
#use parent qw/Math::Matrix::MaybeGSL/;

sub as_list {
    my $self = shift;
    my ($rows, $cols) = $self->dim;
    my @data;
    for my $i (1 .. $rows) {
        for my $j (1 .. $cols) {
            $data[($i-1)*$cols+($j-1)] = $self->element($i, $j);
        }
    }
    return @data;
}

1;
