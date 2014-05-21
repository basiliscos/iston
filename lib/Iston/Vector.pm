package Iston::Vector;

use 5.12.0;

use Carp;
use List::Util qw/reduce/;
use Function::Parameters qw(:strict);

use overload
    '+'  => '_add',
    '*'  => '_mul',
#    'eq' => '_equal',
    '==' => '_equal',
    '""' => '_stringify',
    fallback => 1,
    ;

use parent qw/Exporter/;
our @EXPORT_OK = qw/normal/;

sub new {
    my ($class, $values) = @_;
    croak "Vector is defined exactly by 3 values"
        unless @$values == 3;

    my $copy = [@$values];
    bless $copy => $class;
};

fun normal($vertices, $indices) {
    croak "Normal vector is defined exactly by 3 vertices"
        unless @$indices == 3;
    my @vertices = map { $vertices->[$_] } @$indices;
    my $a = $vertices[0]->vector_to($vertices[1]);
    my $b = $vertices[0]->vector_to($vertices[2]);
    return ($a * $b)->normalize;
}

sub _mul_vector {
    my ($a, $b) = @_;
    my @values = (
        $a->[1]*$b->[2] - $a->[2]*$b->[1],
        $a->[2]*$b->[0] - $a->[0]*$b->[2],
        $a->[0]*$b->[1] - $a->[1]*$b->[0],
    );
    return Iston::Vector->new(\@values);
}

sub _mul_scalar {
    my ($a, $s) = @_;
    my @values = map { $_ * $s } @$a;
    return Iston::Vector->new(\@values);
}

sub _mul {
    my ($a, $b) = @_;
    if (ref($b) eq 'Iston::Vector') {
        return _mul_vector($a, $b);
    } else {
        return _mul_scalar($a, $b);
    }
};


sub _add {
    my ($a, $b) = @_;
    my @r = map { $a->[$_] + $b->[$_] } (0 .. 2);
    return Iston::Vector->new(\@r);
}

sub _equal {
    my ($a, $b) = @_;
    my $r = 1;
    for (0 .. 2) {
        $r &= $a->[$_] == $b->[$_];
    }
    $r;
}

sub length {
    my $self = shift;
    return sqrt(
        reduce  { $a + $b }
            map { $_ * $_ }
            map {$self->[$_] }
            (0 .. 2)
    );
}

sub normalize {
    my $self = shift;
    my $length = $self->length;
    return $self if($length == 0);
    my @r =
        map { $_ / $length  }
        map {$self->[$_] }
        (0 .. 2);
    for (0 .. 2) {
        $self->[$_] = $r[$_];
    }
    $self;
}

sub _stringify {
    my $self = shift;
    return sprintf('vector[%0.4f, %0.4f, %0.4f]', @{$self}[0 .. 2]);
}

1;
