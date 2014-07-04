use 5.12.0;

use Test::More;
use Test::Warnings;

use IO::String;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Analysis::Projections/;
use aliased qw/Iston::Object::HTM/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Analysis::Aberrations/;

my $_PI = 2*atan2(1,0);
my $_G2R = $_PI / 180;

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
    is_deeply $values, [90 * $_G2R];
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
    is_deeply $values, [90 * $_G2R, 90 * $_G2R];

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


done_testing;
