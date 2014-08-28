use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;
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
    );
    is scalar(@{$sphere_vectors->vectors}), 1;
    my $v = $sphere_vectors->vectors->[0];
    is $v, "vector[1.0000, 0.0000, -1.0000]";
    my $mapper = $sphere_vectors->vertex_to_vector_function();
    for (0 .. @angels-1) {
        is $mapper->($_), 0, "vertex $_ maps to vector 0";
    }
};

subtest "sphere vectors :: duplications elimination check" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 0], [0, -90], [-90, -90], [-90, -90], [0, 0]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sv = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    );
    is scalar(@{$sv->vectors}), 3;
    my $mapper = $sv->vertex_to_vector_function;
    is $mapper->(0), 0, "vertex 0 maps to vector 0";
    is $mapper->(1), 0, "vertex 1 maps to vector 0";
    is $mapper->(2), 0, "vertex 2 maps to vector 0";
    is $mapper->(3), 1, "vertex 3 maps to vector 1";
    is $mapper->(4), 2, "vertex 4 maps to vector 2"; # may be 1?
    is $mapper->(5), 2, "vertex 5 maps to vector 2";
};

done_testing;
