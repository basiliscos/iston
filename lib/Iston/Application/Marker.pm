package Iston::Application::Marker;

use 5.12.0;

use Iston::Matrix;
use Iston::Utils qw/rotation_matrix/;
use List::Util qw/reduce/;
use Math::Trig;
use Moo;
use OpenGL qw(:all);
use Path::Tiny;
use SDL;
use SDL::Events;
use SDL::Mouse;
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/AntTweakBar::Type/;
use aliased qw/Iston::Triangle/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Vector/;

with('Iston::Application');

has models_path    => (is => 'ro', required => 1);
has main_object    => (is => 'rw');
has _commands      => (is => 'lazy');

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->_build_menu;
};

sub objects {
    my $self = shift;
    return [ ($self->main_object ? ($self->main_object) : ())  ];
}

sub _load_model {
    my ($self, $model_path) = @_;
    say "loading $model_path";
    my $object = $self->load_object($model_path);
    $self->main_object($object);
    $self->settings_bar->refresh;
}

sub _build_menu {
    my $self = shift;
    my $bar = $self->settings_bar;
    $bar->set_bar_params(
        size        => '350 ' . ($self->height - 50),
        valueswidth => '200');

    my @models =
        sort { $a cmp $b }
        grep { /\.obj$/i }
        path($self->models_path)->children;

    my @model_names = ("choose model", map { $_->basename } @models);
    my $model_type = Type->new("available_models", \@model_names);
    my $model_index = 0;
    $bar->add_variable(
        mode       => 'rw',
        name       => "model",
        type       => $model_type,
        cb_read    => sub { $model_index },
        cb_write   => sub {
            $model_index = shift;
            return if $model_index == 0; # skip "choose model" index;
            $self->_load_model($models[$model_index-1]);
        }
    );

    my $direction = [0.0, 0.0, 1.0];
    my $initial_direction = [0.0, 0.0, 1.0];
    my $x_start = Vector->new(values => [$initial_direction->[0], 0, $initial_direction->[2]]);
    my $y_start = Vector->new(values => [0, $initial_direction->[1], $initial_direction->[2]]);

    $bar->add_variable(
        mode       => 'rw',
        name       => "ObjRotation",
        type       => 'direction',
        definition => " label='Object rotation' opened=true ",
        cb_read    => sub { $direction },
        cb_write   => sub {
            $direction = shift;
            my $x_axis = Vector->new(values => [$direction->[0], 0, $direction->[2]]);
            my $x_angle = $x_axis->is_zero
                ? 0
                : do {
                    my $x_angle = $x_start->angle_with($x_axis);
                    my $x_sign = Vector->new(values => [0, 1, 0])->scalar_multiplication($x_start * $x_axis);
                    $x_sign = ($x_sign < 0) ? -1 : ($x_sign > 0) ? 1 : 0;
                    $x_angle *= $x_sign;
                }
                ;

            my $rotation_matrix = rotation_matrix(0, 1, 0, -1 * $x_angle);

            my $direction = Vector->new(values => [@$direction]);
            my $rolled_back_matrix = $rotation_matrix * Iston::Matrix->new_from_cols([ $direction->values ]);
            my $rolled_back = Vector->new(values => [map { $rolled_back_matrix->element($_, 1) } (1..3) ]);
            say "rb = $rolled_back";

            my $y_angle = $y_start->angle_with($rolled_back);
            say "y angle = ", rad2deg($y_angle);
            my $y_sign = Vector->new(values => [1, 0, 0])->scalar_multiplication($rolled_back * $y_start) * -1;
            $y_sign = ($y_sign < 0) ? -1 : ($y_sign > 0) ? 1 : 0;
            $y_angle *= $y_sign;
            say "y angle = ", rad2deg($y_angle);

            if ($self->main_object) {
                $self->main_object->rotate(0, rad2deg $y_angle);
                $self->main_object->rotate(1, rad2deg $x_angle);
                say "x = ", rad2deg($x_angle), ", y = ", rad2deg($y_angle);
            }
        }
    );
}

sub _build__commands {
    my $self = shift;
    my $rotation = sub {
        my (%step_for) = @_; # key: axis, value: degree
        my $subject = $self->main_object;
        return sub {
            while(my ($axis, $step) = each(%step_for)){
                my $value = $subject->rotate($axis);
                $value += $step;
                $value %= 360;
                $subject->rotate($axis, $value);
            }
        }
    };
    my $camera_z_move = sub {
        my $value = shift;
        return sub {
            $self->camera_position->[2] += $value;
            $self->_update_view;
        };
    };
    my $rotate_step = 2;
    my $commands = {
        'rotate_N'    => $rotation->(0, -$rotate_step),
        'rotate_S'    => $rotation->(0, $rotate_step),
        'rotate_W'    => $rotation->(1, -$rotate_step),
        'rotate_E'    => $rotation->(1, $rotate_step),
        'rotate_NW'   => $rotation->(0, -$rotate_step, 1, -$rotate_step),
        'rotate_NE'   => $rotation->(0, -$rotate_step, 1, $rotate_step),
        'rotate_SW'   => $rotation->(0, $rotate_step, 1, -$rotate_step),
        'rotate_SE'   => $rotation->(0, $rotate_step, 1, $rotate_step),
        'move_camera_forward'  => $camera_z_move->(0.1),
        'move_camera_backward' => $camera_z_move->(-0.1),
        'terminate_program'    => sub { $self->sdl_app->stop },
    };
    return $commands;
}

sub process_event {
    my ($self, $event) = @_;
    # say "processing event...";
    my $action;
    AntTweakBar::eventSDL($event);
    if ($event->type == SDL_QUIT) {
        $action = $self->_commands->{'terminate_program'};
    }
    if ($action) {
        $action->();
    }
}

1;
