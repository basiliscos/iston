use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;
use aliased qw/Iston::Object::SphereVectors::GeneralizedVectors/;
use aliased qw/Iston::Vertex/;

my $ts_idx = 0;
my $_a2r = sub {
    my $angles = shift;
    return [ map  {
        my ($a, $b, $z) = @$_;
        $z //= -7;
        Record->new(
            timestamp     => $ts_idx++,
            x_axis_degree => $a,
            y_axis_degree => $b,
            camera_x      => 0,
            camera_y      => 0,
            camera_z      => $z,
        );
    } @$angles ] ;
};

subtest "sphere vectors :: vectorized vertices" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 0], [0, -90] );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sphere_vectors = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    )->vectors;
    is scalar(@$sphere_vectors), 1;
    is $sphere_vectors->[0], "vector[1.0000, 0.0000, -1.0000]";
};

subtest "sphere vectors :: generalized vectors on equator" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 10], [0, 45], [0, 90] );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sphere_vectors_original = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    )->vectors;
    my $sphere_vectors = GeneralizedVectors->new(
        distance       => 0.01,
        source_vectors => $sphere_vectors_original,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    )->vectors;
    is scalar(@$sphere_vectors), 1;
    is $sphere_vectors->[0], "vector[0.0000, 0.0000, -1.0000]";
};

subtest "sphere vectors :: no generalized vectors" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 90], [90, 90] );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sphere_vectors_original = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    )->vectors;
    my $sphere_vectors = GeneralizedVectors->new(
        distance       => 0.01,
        source_vectors => $sphere_vectors_original,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    )->vectors;
    is scalar(@$sphere_vectors), 2;
    is $sphere_vectors->[0], "vector[-1.0000, 0.0000, -1.0000]";
    is $sphere_vectors->[1], "vector[1.0000, 1.0000, -0.0000]";
};


done_testing;
