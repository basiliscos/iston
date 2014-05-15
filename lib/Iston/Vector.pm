package Iston::Vector;

use 5.12.0;

use Carp;
use List::Util qw/reduce/;

use overload
    '+'  => '_add',
    'eq' => '_equal',
    '==' => '_equal',
    '""' => '_stringify',
    ;

sub new {
    my ($class, $values) = @_;
    croak "Vector is defined exactly by 3 values"
        unless @$values == 3;

    my $copy = [@$values];
    bless $copy => $class;
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
