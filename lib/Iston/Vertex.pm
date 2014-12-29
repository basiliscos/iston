package Iston::Vertex;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::Utils qw/as_cartesian/;
use Moo;

use aliased qw/Iston::Vector/;

use overload
    '""' => '_stringify',
     fallback => 1,
   ;

with('Iston::Payload');

has 'values' => (is => 'ro', required => 1);

method vector_to($vertex_b) {
    my ($a, $b) = map {$_->values} ($self, $vertex_b);
    my @values = map { $b->[$_] - $a->[$_] } (0 .. 2);
    return Vector->new(values => \@values);
};

sub _stringify {
    my $values = shift->values;
    return sprintf('vertex[%0.7f, %0.7f, %0.7f]', @$values);
}

1;
