package Iston::Application::Observer;

use 5.12.0;

use Moo;
use OpenGL qw(:all);
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::History::Record/;

with('Iston::Application');

has started_at  => (is => 'ro', default => sub { [gettimeofday]} );
has object_path => (is => 'ro', required => 1);
has main_object => (is => 'rw');

sub BUILD {
    my $self = shift;
    $self->init_app;
    my $object = $self->load_object($self->object_path);
    $self->main_object($object);
    push @{ $self->objects }, $object;
    $self->_log_state;
};

sub objects {
    my $self = shift;
    return [$self->main_object];
}

sub _log_state {
    my $self = shift;

    return unless $self->history;
    my $record = Record->new(
        timestamp     => tv_interval ( $self->started_at, [gettimeofday]),
        x_axis_degree => $self->main_object->rotation->[0],
        y_axis_degree => $self->main_object->rotation->[1],
        camera_x      => $self->camera_position->[0],
        camera_y      => $self->camera_position->[1],
        camera_z      => $self->camera_position->[2],
    );
    push @{ $self->history->records }, $record;
}

sub _exit {
    my $self = shift;
    say "...exiting from observer";
    $self->_log_state;
    $self->history->save if($self->history);
    $self->cv_finish->send;
}

sub key_pressed {
    my ($self, $key) = @_;
    my $rotate_step = 2;
    my $rotation = sub {
        my ($c, $step) = @_;
        my $subject = $self->main_object;
        return sub {
            $subject->rotation->[$c] += $step;
            $subject->rotation->[$c] %= 360;
        }
    };
    my $camera_z_move = sub {
        my $value = shift;
        return sub {
            $self->camera_position->[2] += $value;
        };
    };
    my $dispatch_table = {
        'w' => $rotation->(0, -$rotate_step),
        's' => $rotation->(0, $rotate_step),
        'a' => $rotation->(1, -$rotate_step),
        'd' => $rotation->(1, $rotate_step),
        '+' => $camera_z_move->(0.1),
        '-' => $camera_z_move->(-0.1),
        'q' => sub {
            my $m = glutGetModifiers;
            $self->_exit if($m & GLUT_ACTIVE_ALT);
        },
    };
    my $key_char = chr($key);
    my $action = $dispatch_table->{$key_char};
    $action->() if($action);
    $self->_log_state;
}

1;
