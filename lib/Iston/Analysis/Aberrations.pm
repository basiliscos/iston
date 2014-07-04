package Iston::Analysis::Aberrations;
# Abstract: Tracks the (angle) direction changes of the observation path

use 5.12.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use List::MoreUtils qw/pairwise/;
use Math::MatrixReal;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

my $_PI = 2*atan2(1,0);
my $_G2R = $_PI / 180;

has 'projections'    => (is => 'ro', required => 1);
has 'sphere_vectors' => (is => 'lazy');
has 'values'         => (is => 'lazy');

method _build_sphere_vectors {
    my $observation_path = $self->projections->observation_path;
    my $vertices = $observation_path->vertices;
    my $indices = $observation_path->sphere_vertex_indices;
    my @vectors = map {
        my @uniq_indices = @{$indices}[$_, $_+1];
        my ($a, $b) = map { $vertices->[$_] } @uniq_indices;
        $a->vector_to($b);
    } (0 .. @$indices - 2);
    return \@vectors;
};

method _build_values {
    my $observation_path = $self->projections->observation_path;
    my $vertices = $observation_path->vertices;
    my $indices = $observation_path->sphere_vertex_indices;
    my @middle_points = map {
        my $idx = $indices->[$_];
        my ($m, $n) = map { $vertices->[$_] } $idx, $idx+1;
        my $coords = [ pairwise { ($a + $b)/2 } @$m, @$n ];
        Vertex->new($coords);
    } (0 .. @$indices - 2);
    my $center = Vertex->new([0, 0, 0]);
    my @auxilary_vectors = map { $center->vector_to($_) } @middle_points;
    my $sphere_vectors = $self->sphere_vectors;
    my @normals = pairwise { $a * $b } @$sphere_vectors, @auxilary_vectors;
    my @normal_degrees = map {
        my ($n1, $n2) = map { $normals[$_] } $_, $_+1;
        $n1->angle_with($n2);
    } (0 .. @normals -2 );
    return \@normal_degrees;
}

method dump_analisys ($output_fh) {
    my $observation_path = $self->projections->observation_path;
    my $vertices = $observation_path->vertices;
    my $v2s = $observation_path->vertex_to_sphere_index;
    my $values = $self->values;
    say $output_fh "vertex_index, aberration";
    for my $idx (0 .. @$vertices -1) {
        my $sphere_index = $v2s->[$idx];
        my $vector_index = $sphere_index - 1;
        my $value_index  = $vector_index - 1;
        my $value = 0;
        if ($value_index >= 0 && $v2s->[$idx-1] != $sphere_index) {
            $value = $values->[$value_index];
        }
        $value = sprintf('%0.2f', $value / $_G2R);
        say $output_fh "$idx, $value";
    }
}

1;
