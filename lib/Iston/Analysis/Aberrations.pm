package Iston::Analysis::Aberrations;
# Abstract: Tracks the (angle) direction changes of the observation path

use 5.12.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use List::MoreUtils qw/pairwise/;
use List::Util qw/reduce/;
use Math::Trig;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'sphere_vectors' => (is => 'ro', required => 1);
has 'values'         => (is => 'lazy');

method _build_values() {
    my $sphere_vectors = $self->sphere_vectors->vectors;
    my @normal_degrees = map {
        my ($v1, $v2) = map { $sphere_vectors->[$_] } $_, $_+1;
        my ($n1, $n2) = map { $_->payload->{great_arc_normal} } ($v1, $v2);
        my $angle = $n1->angle_with($n2);
        if ($angle) {
            my $sign =
                reduce {$a + $b}
                map {
                    my $idx = $_;
                    my ($c, $c0) =
                        map { $_->payload->{end_vertex}->values->[$idx] }
                        ($v2, $v1);
                    $n1->values->[$_]*($c-$c0);
                } (0 .. 2);
            $angle *= ($sign > 0) ? 1 : -1;
        }
        $angle;
    } (0 .. @$sphere_vectors - 2);
    return \@normal_degrees;
}

method iterate($observation_path, $cb) {
    my $vertices = $observation_path->vertices;
    my $v2s = $observation_path->vertex_to_sphere_index;
    my $values = $self->values;
    my $mapper = $self->sphere_vectors->vertex_to_vector_function;
    for my $idx (0 .. @$vertices -1) {
        my $sphere_index = $v2s->[$idx];
        my $vector_index = $mapper->($idx) // 0; # $sphere_index - 1;
        my $value_index  = $vector_index - 1;
        my $value = 0;
        if ($vector_index > 0 && $v2s->[$idx-1] != $sphere_index) {
            $value = $values->[$value_index];
        }
        $cb->($idx, $value);
    }
}

method dump_analisys ($output_fh, $observation_path) {
    say $output_fh "vertex_index, aberration";
    $self->iterate($observation_path, sub {
        my ($idx, $value) = @_;
        say $output_fh $idx, ', ', sprintf('%0.2f', rad2deg($value));
    });
}

1;
