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
use aliased qw/Iston::Analysis::AngularVelocity/;

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

subtest "simple case: rotation in the same plane" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, -90], [0, -180], [0, -270], [0, 0]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $av = AngularVelocity->new( observation_path => $o );
    my $values = $av->values;
    is_deeply $values, [map { deg2rad($_) } 90, 90, 90, 90];

    my $out = IO::String->new;
    $av->dump_analisys($out);
    my $result = ${$out->string_ref};
    is $result, <<RESULT
vertex_index, velocity(degree/sec)
0, 0.00
1, 90.00
2, 90.00
3, 90.00
4, 90.00
RESULT
};

subtest "simple case, east pole, north pole" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, -90], [-90, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $av = AngularVelocity->new( observation_path => $o );
    my $values = $av->values;
    is_deeply $values, [map { deg2rad($_) } 90, 90];

    my $out = IO::String->new;
    $av->dump_analisys($out);
    my $result = ${$out->string_ref};
    is $result, <<RESULT
vertex_index, velocity(degree/sec)
0, 0.00
1, 90.00
2, 90.00
RESULT
};

subtest "simple case, east pole, north pole (duplications check)" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, -90], [-90, -90], [-90, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $av = AngularVelocity->new( observation_path => $o );
    my $values = $av->values;
    is_deeply $values, [map { deg2rad($_) } 90, 90];

    my $out = IO::String->new;
    $av->dump_analisys($out);
    my $result = ${$out->string_ref};
    is $result, <<RESULT
vertex_index, velocity(degree/sec)
0, 0.00
1, 90.00
2, 90.00
3, 0.00
RESULT
};


done_testing;
