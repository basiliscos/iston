package Iston::Plugin::Inertion;

use strict;
use warnings;
use Math::Trig;
use Moo;
use Path::Tiny;
use SDL::Events;

has app         => (is => 'ro', required => 1);
has thrust      => (is => 'ro', required => 1);
has friction    => (is => 'ro', required => 1);
has records     => (is => 'rw');
has last_record => (is => 'rw');
has timer       => (is => 'rw');

sub BUILD(@) {
    my $self = shift;
    print "Instantiating ", __PACKAGE__, "\n";
    my $app = $self->app;
    $self->records($app->history->records);
    $self->last_record(0);
}

sub process_event { }

sub postprocess_event {
    my ($self, $event) = @_;
    my $records = $self->records;
    my $last_idx = 0;
    for (my $i = @$records - 1; $i >= 0; --$i) {
        my $label = $records->[$i]->label // '';
        if ($label ne 'S') {
            $last_idx = $i;
            last;
        }
    }
    if ($self->last_record != $last_idx) {
        $self->spawn_timer($last_idx);
        $self->last_record($last_idx);
    }
}

my $freq = 0.0001;

sub spawn_timer {
    my ($self, $last_idx) = @_;
    return if $last_idx < 2;

    my ($x2, $y2, $t2) = map { $self->records->[$last_idx - 0]->$_ } qw/x_axis_degree y_axis_degree timestamp/;
    my ($x1, $y1, $t1) = map { $self->records->[$last_idx - 1]->$_ } qw/x_axis_degree y_axis_degree timestamp/;
    my $dx = ($x2 + 360) - ($x1  + 360);
    my $dy = ($y2 + 360) - ($y1 + 360);
    my $dt = $t2 - $t1;

    my $thrust = $self->thrust;
    my $friction = $self->friction;

    my $ux = $thrust * $dx * $freq / $dt;
    my $uy = $thrust * $dy * $freq / $dt;

    my $t = AE::timer $freq, $freq, sub {
        $self->app->rotate_objects($uy, $ux);
        ($uy, $ux) = map { $_ * (1 - $friction) } ($uy, $ux);
        $self->app->_log_state('S');
    };
    $self->timer($t);
}

sub on_exit {
    my $self = shift;
    $self->timer(undef);
}

1;

