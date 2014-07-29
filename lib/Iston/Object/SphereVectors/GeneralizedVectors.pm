package Iston::Object::SphereVectors::GeneralizedVectors;

use 5.16.0;

use Function::Parameters qw(:strict);
use List::Util qw(max);
use Math::Trig;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'source_vectors' => (is => 'ro', required => 1);
has 'distance'       => (is => 'ro', required => 1);
has 'vectors'        => (is => 'lazy');
has 'vertices'       => (is => 'lazy');
has 'vertex_indices' => (is => 'lazy');

with('Iston::Object::SphereVectors');

method _build_vectors {
    # Ramer-Douglas-Peucker algorithm applied to the sphere's great arc
    my $source_vectors = $self->source_vectors;
    my @vectors;
    my $last_index = -1;
    for my $i (0 .. @$source_vectors-1) {
        next if $i <= $last_index;
        $last_index = $i;
        my $start = $source_vectors->[$i];
        for my $j ($i+1 .. @$source_vectors-1) {
            my $distance = _max_distance($source_vectors, $i, $j);
            if($distance <= $self->distance){
                $last_index = $j;
            }
            else {
                last;
            };
        }
        if ($last_index > $i) {
            my $a = $start->payload->{start_vertex};
            my $b = $source_vectors->[$last_index]->{end_vertex};
            my $v = $a->vector_to($b);
            $v->payload->{start_vertex} = $a;
            $v->payload->{end_vertex  } = $b;
            push @vectors, $v;
        }
        else {
            push @vectors, $start;
        }
    }
    return \@vectors;
};

my $_center = Vertex->new([0, 0, 0]);
my $_halfpi = pi/2;

fun _max_distance($vectors, $start_idx, $end_idx) {
    my $a = $vectors->[$start_idx]->payload->{start_vertex};
    my $b = $vectors->[$start_idx]->payload->{end_vertex};
    my $great_arc_normal = $a->vector_to($b) * $_center->vector_to($a);
    my $distance = max( map {
        my $v = $vectors->[$_];
        my ($d1, $d2) =
            map { $_halfpi - $_ }
            map { $_->angle_with($great_arc_normal) }
            map {
                $_center->vector_to($_)
            }
            ($v->payload->{start_vertex}, $v->payload->{end_vertex});
        ($d1, $d2);
    } ($start_idx .. $end_idx) );
    return $distance;
}

1;
