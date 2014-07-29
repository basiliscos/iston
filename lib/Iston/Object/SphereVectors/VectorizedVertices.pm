package Iston::Object::SphereVectors::VectorizedVertices;

use 5.16.0;

use Function::Parameters qw(:strict);
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'vertices'       => (is => 'ro', required => 1);
has 'vectors'        => (is => 'lazy');
has 'vertex_indices' => (is => 'ro', required => 1);

with('Iston::Object::SphereVectors');

method _build_vectors {
    my $vertices = $self->vertices;
    my $indices = $self->vertex_indices;
    my $center = Vertex->new([0, 0, 0]);
    my @vectors = map {
        my @uniq_indices = @{$indices}[$_, $_+1];
        my ($a, $b) = map { $vertices->[$_] } @uniq_indices;
        my $v = $a->vector_to($b);
        my $great_arc_normal = $v * $center->vector_to($a);
        $v->payload->{start_vertex    } = $a;
        $v->payload->{end_vertex      } = $b;
        $v->payload->{great_arc_normal} = $great_arc_normal;
        $v;
    } (0 .. @$indices - 2);
    return \@vectors;
};


1;
