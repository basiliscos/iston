use 5.16.0;
use utf8;

use Path::Tiny;
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

subtest "simple spin" => sub {
    my $h = History->new;
    # spin rotation like:
    #  ←
    # ↙ ↖
    #↓   ↑
    # ↘ ↗
    #  →
    my @angels = (
        [0, 0],                   # start position
        [0, 2],  [0, 4],          # → →
        [358, 6], [356, 8],       # ↗ ↗
        [354, 8], [352, 8],       # ↑ ↑
        [350, 6], [348, 4],       # ↖ ↖
        [348, 2], [348, 0],       # ← ←
        [350, 358], [352,356],    # ↙ ↙
        [354, 356], [356,356],    # ↓ ↓
        [358, 358], [0, 0],       # ↘ ↘
    );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sphere_vectors_original = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    );
    my $gv = GeneralizedVectors->new(
        distance       => 0.01,
        source_vectors => $sphere_vectors_original,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    );
    is scalar(@{$gv->vectors}), 8;

    subtest "vectorized vertices spins" => sub{
        my $vv = $sphere_vectors_original;
        $vv->spin_detection(1);
        is $vv->vectors->[$_]->payload->{spin_index}, 0, "0-th spin for $_ vv"
            for (0 .. @{ $vv->vectors } - 1);
        $vv->spin_detection(0);
        ok !exists $vv->vectors->[$_]->payload->{spin_index}, "no spin for $_ vv"
            for (0 .. @{ $vv->vectors } - 1);
    };

    subtest "gv spins" => sub {
        $gv->spin_detection(1);
        is $gv->vectors->[$_]->payload->{spin_index}, 0, "0-th spin for $_ gv"
            for (0 .. @{ $gv->vectors } - 1);
        $gv->spin_detection(0);
        ok !exists $gv->vectors->[$_]->payload->{spin_index},  "no spin for $_ gv"
            for (0 .. @{ $gv->vectors } - 1);
    };

};

subtest "no spin" => sub {
    my $h = History->new;
    # rotation like:
    #  →↗↘
    my @angels = (
        [0, 0],   # start
        [0, 10],  # →
        [5, 15],  # ↗
        [-5, 20], # ↘
        [5, 25],  # ↗
    );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $vv = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.0, 0.0, 0.0, 0.0], # does not matter
    );
    $vv->spin_detection(1);
    ok !exists $_->payload->{spin_index} for (@{ $vv->vectors });
};


done_testing;
