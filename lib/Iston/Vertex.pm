package Iston::Vertex;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);

use aliased qw/Iston::Vector/;

use overload
    '""' => '_stringify',
     fallback => 1,
   ;

sub new {
    my ($class, $values) = @_;
    croak "Vertex is defined exactly by 3 values"
        unless @$values == 3;

    my $copy = [@$values];
    bless $copy => $class;
};

method vector_to($vertex_b) {
    my ($a, $b) = ($self, $vertex_b);
    my @values = map { $b->[$_] - $a->[$_] } (0 .. 2);
    return Vector->new(\@values);
};

sub _stringify {
    my $self = shift;
    return sprintf('vertex[%0.7f, %0.7f, %0.7f]', @{$self}[0 .. 2]);
}

1;
