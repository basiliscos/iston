package Iston::Application::Observer;

use 5.12.0;

use Moo;
use OpenGL qw(:all);
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Triangle/;
use aliased qw/Iston::Vertex/;

with('Iston::Application');

has started_at     => (is => 'ro', default => sub { [gettimeofday]} );
has object_path    => (is => 'ro', required => 1);
has main_object    => (is => 'rw');
has mouse_position => (is => 'rw');

sub BUILD {
    my $self = shift;
    $self->init_app;
    my $object = 
        # Triangle->new(
        #     vertices    => [
        #         Vertex->new([1, 0, 0]),
        #         Vertex->new([-1, 0, 0]),
        #         Vertex->new([0, 1, 0]),
        #     ],
        #     tesselation => 1,
        # );
        $self->load_object($self->object_path);
    # $object->normals([
    #     $object->normal,
    #     $object->normal,
    #     $object->normal,
    # ]);
    $self->main_object($object);
    push @{ $self->objects }, $object;

    my ($x, $y) = ($self->width/2, $self->height/2);
    glutWarpPointer($x, $y);
    $self->mouse_position([$x, $y]);

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
        x_axis_degree => $self->main_object->rotate(0),
        y_axis_degree => $self->main_object->rotate(1),
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
        my ($axis, $step) = @_;
        my $subject = $self->main_object;
        return sub {
            my $value = $subject->rotate($axis);
            $value += $step;
            $value %= 360;
            $subject->rotate($axis, $value);
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

sub mouse_movement {
    my ($self, $x, $y) = @_;

    # guard the edges
    my $barrier = 30;
    my $reset_position = 0;
    ($reset_position, $x) = (1, $self->width/2)
        if ($x < $barrier or $self->width - $x < $barrier);
    ($reset_position, $y) = (1, $self->height/2)
        if ($y < $barrier or $self->height -$y < $barrier);
    if ($reset_position) {
        glutWarpPointer($x, $y);
        return $self->mouse_position( [$x, $y] );
    }

    my $last_position = $self->mouse_position;
    my ($dX, $dY) = ($last_position->[0] - $x, $last_position->[1] - $y);

    my @rotations = map { $_ * -1} ($dY, $dX);
    my $rot_x = $self->main_object->rotate(0);
    for my $axis (0 .. @rotations-1) {
        my $value = $self->main_object->rotate($axis);
        $value += $rotations[$axis];
        $value %= 360;
        $self->main_object->rotate($axis, $value);
    }
    $self->_log_state;
    $self->mouse_position( [$x, $y] );
    glutPostRedisplay;
}

sub mouse_click {
    my ($self, $button, $state, $x, $y) = @_;
    if ($button == 3 or $button == 4) { # scroll event
        if (!$state != GLUT_UP) {
            my $step = 0.1 * ( ($button == 3) ? 1: -1);
            $self->camera_position->[2] += $step;
        }
    }
}

1;
