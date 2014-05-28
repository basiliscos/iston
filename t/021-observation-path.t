use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Object::ObservationPath/;

subtest "simple 2 point path" => sub {
    my $h = History->new;
    my @angels = ([0,0], [0, 90]);
    my @records = map {
        my ($a, $b) = @$_;
        Record->new(
            timestamp => 0,
            alpha     => $a,
            beta      => $b,
            camera_x  => 0,
            camera_y  => 0,
            camera_z  => -7,
        );
    } @angels;
    push @{$h->records}, @records;
    my $o = ObservationPath->new(history => $h);
    is @{$o->indices}, 2;
    is $o->indices->[0], 0;
    is $o->indices->[1], 1;

    is @{$o->vertices}, 2;
    is $o->vertices->[0], "vertex[0.0000000, 0.0000000, 1.0000000]";
    is $o->vertices->[1], "vertex[1.0000000, 0.0000000, 0.0000000]";
};

done_testing;
