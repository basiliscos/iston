package Iston::Vertex;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::Utils qw/as_cartesian/;
use Moo;

use aliased qw/Iston::Vector/;

use overload
    '""' => '_stringify',
    '@{}' => '_values',
     fallback => 1,
   ;

with('Iston::Payload');

has 'values' => (is => 'ro', required => 1);

sub _values { return shift->values; }

sub BUILDARGS {
    my ( $class, $values ) = @_;
    return { values => [@$values] };
}

method vector_to($vertex_b) {
    my ($a, $b) = ($self, $vertex_b);
    my $v;
    my @values = map { $b->[$_] - $a->[$_] } (0 .. 2);
    $v = Vector->new(\@values);
    return $v;
};

sub _stringify {
    my $self = shift;
    return sprintf('vertex[%0.7f, %0.7f, %0.7f]', @{$self}[0 .. 2]);
}

1;
