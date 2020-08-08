use 5.16.0;
use utf8;

use IO::String;
use Path::Tiny;
use Test::More;
use Test::Warnings;
use Math::Trig;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Zone/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;
use aliased qw/Iston::Object::MarkerContainer/;
use aliased qw/Iston::Analysis::Aberrations/;
use aliased qw/Iston::EventDistributor/;


my $_a2r = sub {
    my $ts_idx = 0;
    my $angles = shift;
    return [ map  {
        my ($a, $b) = @$_;
        Record->new(
            timestamp     => $ts_idx++,
            x_axis_degree => $a,
            y_axis_degree => $b,
            camera_x      => 0,
            camera_y      => 0,
            camera_z      => -7,
        );
    } @$angles ] ;
};

my $notifyer = EventDistributor->new;
$notifyer->declare('view_change');

subtest "simple case" => sub {
    my $z = Zone->new(
        xz     => 0,
        yz     => 0,
        spread => 10,
    );
    my $mc = MarkerContainer->new({ notifyer => $notifyer});
    push @{ $mc->zones }, $z;

    my $h = History->new;
    my @angels = ([0, 0], [0, -90], [0, -180], [0, -270], [0, 0]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sv = VectorizedVertices->new(
        vertices       => $o->vertices,
        vertex_indices => $o->sphere_vertex_indices,
        hilight_color  => [0.75, 0.0, 0.0, 1.0], # does not matter
    );
    $o->sphere_vectors($sv);
    my $out = IO::String->new;
    $mc->dump_analisys($out, $o);
    my $result = ${$out->string_ref};
    is ($result, <<RESULT);
vertex_index, distance_1, deviation_1
0, 0.00, 0.00
1, 90.00, 0.00
2, 180.00, 0.00
3, 90.00, 0.00
4, 0.00, 0.00
RESULT

    is_deeply( $mc->calc_distances($o->vertices->[0]), [0] );
    is_deeply( $mc->calc_distances($o->vertices->[1]), [deg2rad 90] );
};


done_testing;
