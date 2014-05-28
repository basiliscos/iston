use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Object::ObservationPath/;

my $ts_idx = 0;
my $_a2r = sub {
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

subtest "simple 2 point path" => sub {
    my $h = History->new;
    my @angels = ([0,0], [0, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    is @{$o->indices}, 2;
    is $o->indices->[0], 0;
    is $o->indices->[1], 1;

    is @{$o->vertices}, 2;
    is $o->vertices->[0], "vertex[0.0000000, 0.0000000, 1.0000000]";
    is $o->vertices->[1], "vertex[1.0000000, 0.0000000, 0.0000000]";

    is $o->index_at->{ $h->records->[-1]->timestamp }, 1;
};

subtest "up: 45, counter-clock-wise: 90" => sub {
    my $h = History->new;
    my @angels = ([0,0], [45, 0], [45, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);

    is @{$o->vertices}, 3;
    is $o->vertices->[0], "vertex[0.0000000, 0.0000000, 1.0000000]";
    is $o->vertices->[1], "vertex[0.0000000, 0.7071068, 0.7071068]";
    is $o->vertices->[2], "vertex[0.7071068, 0.7071068, 0.0000000]";

    is $o->index_at->{ $h->records->[-1]->timestamp }, 2;
};

done_testing;
