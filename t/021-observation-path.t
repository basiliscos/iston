use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Object::ObservationPath/;
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

subtest "simple 2 point path" => sub {
    my $h = History->new;
    my @angels = ([0,0], [0, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);

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

subtest "simple arrow vertices" => sub {
    my $h = History->new;
    my @angels = ([0,0], [0, -90]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);

    is @{$o->vertices}, 2;
    # for simplification
    $o->vertices->[0] = Vertex->new([2, 0, 0]);
    $o->vertices->[1] = Vertex->new([4, 0, 0]);
    is $o->vertices->[0], "vertex[2.0000000, 0.0000000, 0.0000000]";
    is $o->vertices->[1], "vertex[4.0000000, 0.0000000, 0.0000000]";
    my @arrows = $o->arrow_vertices(1, 0);
    is scalar(@arrows), 4, "got exactly 4 arrow points";
    my ($v1, $v2, $v3, $v4) = @arrows;
    is $v1->smart_2string, 'vector[2.0000, -1.0000, 0.0000]';
    is $v2->smart_2string, 'vector[2.0000, 0.0000, -1.0000]';
    is $v3->smart_2string, 'vector[2.0000, 1.0000, 0.0000]';
    is $v4->smart_2string, 'vector[2.0000, 0.0000, 1.0000]';
};

subtest "sphere vertices: simple case" => sub {
    my $h = History->new;
    my @angels = ([0,0], [0,0], [0, -90], [0, -90], [0, 0]);
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $unique = $o->sphere_vertex_indices;
    is_deeply $unique, [0, 2, 4];
    my $orig_to_uniq = $o->vertex_to_sphere_index;
    is_deeply $orig_to_uniq, [0, 0, 1, 1, 2];
};

subtest "sphere vectors creation" => sub {
    my $h = History->new;
    my @angels = ([0, 0], [0, 0], [0, -90] );
    my $records = $_a2r->(\@angels);
    push @{$h->records}, @$records;
    my $o = ObservationPath->new(history => $h);
    my $sphere_vectors = $o->sphere_vectors->vectors;
    is scalar(@$sphere_vectors), 1;
    is $sphere_vectors->[0], "vector[1.0000, 0.0000, -1.0000]";
};

done_testing;
