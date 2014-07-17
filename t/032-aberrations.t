use 5.12.0;

use Test::More;
use Test::Warnings;

use IO::String;
use Math::Trig;
use Path::Tiny;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Analysis::Projections/;
use aliased qw/Iston::Object::HTM/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Analysis::Aberrations/;

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

subtest "sphere vertices creation" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 0], [0, -90] );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $htm = HTM->new;
    $htm->level(1);
    my $projections = Projections->new(
        observation_path => $o,
        htm              => $htm,
    );
    my $abb = Aberrations->new( projections => $projections );
    my $sphere_vectors = $abb->sphere_vectors;
    is scalar(@$sphere_vectors), 1;
    is $sphere_vectors->[0], "vector[1.0000, 0.0000, -1.0000]";
};

subtest "simple case: rotation in the same plane: no aberrations" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, -90], [0, -180], [0, -270], [0, 0]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $htm = HTM->new;
    $htm->level(1);
    my $projections = Projections->new(
        observation_path => $o,
        htm              => $htm,
    );
    my $abb = Aberrations->new( projections => $projections );
    my $values = $abb->values;
    is_deeply $values, [0, 0, 0];

    my $out = IO::String->new;
    $abb->dump_analisys($out);
    my $result = ${$out->string_ref};
    is $result, <<RESULT
vertex_index, aberration
0, 0.00
1, 0.00
2, 0.00
3, 0.00
4, 0.00
RESULT
};

subtest "simple case, east pole, north pole" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, -90], [-90, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $htm = HTM->new;
    $htm->level(1);
    my $projections = Projections->new(
        observation_path => $o,
        htm              => $htm,
    );
    my $abb = Aberrations->new( projections => $projections );
    my $values = $abb->values;
    is_deeply $values, [deg2rad 90];
};

subtest "vertices duplication check output" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 0], [0, -90], [-90, -90], [-90, -90], [0, 0]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $htm = HTM->new;
    $htm->level(1);
    my $projections = Projections->new(
        observation_path => $o,
        htm              => $htm,
    );
    my $abb = Aberrations->new( projections => $projections );
    my $values = $abb->values;
    is_deeply $values, [deg2rad(90), deg2rad(90)];

    my $out = IO::String->new;
    $abb->dump_analisys($out);
    my $result = ${$out->string_ref};
    is $result, <<RESULT
vertex_index, aberration
0, 0.00
1, 0.00
2, 0.00
3, 90.00
4, 0.00
5, 90.00
RESULT
};


# actually we check here that no warning has been emitted
# due to accidental jump into Complex plane
subtest "too small values (from file)" => sub {
    my $tmp_dir = Path::Tiny->tempdir( CLEANUP => 1);
    my $data =<<DATA;
timestamp,x_axis_degree,y_axis_degree,camera_x,camera_y,camera_z
17.621475,16,262,0,0,-7.5
17.67218,15,262,0,0,-7.5
17.672505,15,262,0,0,-7.5
17.722267,14,262,0,0,-7.5
17.722533,14,262,0,0,-7.5
DATA
    my $data_path = path($tmp_dir, "x.csv");
    $data_path->spew($data);
    my $h = History->new(path => $data_path);
    $h->load;
    is $h->elements, 5, "5 history records";
    my $o = ObservationPath->new(history => $h);
    my $htm = HTM->new;
    $htm->level(3);
    my $projections = Projections->new(
        observation_path => $o,
        htm              => $htm,
    );
    my $abb = Aberrations->new( projections => $projections );
    my $values = $abb->values;
    my $out = IO::String->new;
    $abb->dump_analisys($out);
    ok $out;
};

TODO: {
    local $TODO = "the small discrete abberations should be smoothed";

    subtest "false aberrations (from file)" => sub {
        my $tmp_dir = Path::Tiny->tempdir( CLEANUP => 1);
        my $data =<<DATA;
timestamp,x_axis_degree,y_axis_degree,camera_x,camera_y,camera_z
4.656869,16,357,0,0,-7
4.706522,17,357,0,0,-7
4.806400,18,357,0,0,-7
4.806714,18,356,0,0,-7
4.856375,19,356,0,0,-7
5.356476,19,355,0,0,-7
5.356776,19,354,0,0,-7
5.406493,18,353,0,0,-7
5.456197,18,352,0,0,-7
5.456494,18,351,0,0,-7
DATA
        my $data_path = path($tmp_dir, "x.csv");
        $data_path->spew_utf8($data);
        my $h = History->new(path => $data_path);
        $h->load;
        my $o = ObservationPath->new(history => $h);
        my $htm = HTM->new;
        $htm->level(3);
        my $projections = Projections->new(
            observation_path => $o,
            htm              => $htm,
        );
        my $abb = Aberrations->new( projections => $projections );
        my $values = $abb->values;
        for my $v (@$values) {
            my $d = rad2deg($v);
            ok $d < 20, "aberration $d is less then 20";
        }
    };
};

done_testing;
