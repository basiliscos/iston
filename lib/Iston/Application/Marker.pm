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

    my $direction_xz = [0.0, 0.0, 1.0];
    my $initial_direction_xz = [0.0, 0.0, 1.0];
    my $xz_start = Vector->new(values => [$initial_direction_xz->[0], 0, $initial_direction_xz->[2]]);
    my $xz_angle = 0;

    $bar->add_variable(
        mode       => 'rw',
        name       => "zx-orientation",
        type       => 'direction',
        definition => " label='zx-orientation' opened=true ",
        cb_read    => sub { $direction_xz },
        cb_write   => sub {
            $direction_xz = shift;
            $direction_xz->[1] = 0;
            $direction_xz = Vector->new(values => $direction_xz)->normalize->values;

            my $xz_axis = Vector->new(values => [$direction_xz->[0], 0, $direction_xz->[2]]);
            $xz_angle = $xz_axis->is_zero
                ? 0
                : do {
                    my $xz_angle = $xz_start->angle_with($xz_axis);
                    my $xz_sign = Vector->new(values => [0, 1, 0])->scalar_multiplication($xz_start * $xz_axis);
                    $xz_sign = ($xz_sign < 0) ? -1 : ($xz_sign > 0) ? 1 : 0;
                    $xz_angle *= $xz_sign;
                };
            $self->settings_bar->refresh;
            if ($self->main_object) {
                $self->main_object->rotate(1, rad2deg $xz_angle);
            }
        }
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "zx-angle",
        type       => 'number',
        cb_read    => sub { rad2deg $xz_angle },
    );

    my $direction_yz = [0.0, 0.0, 1.0];
    my $initial_direction_yz = [0.0, 0.0, 1.0];
    my $yz_start = Vector->new(values => [$initial_direction_yz->[0], 0, $initial_direction_yz->[2]]);
    my $yz_angle = 0;

    $bar->add_variable(
        mode       => 'rw',
        name       => "yx-orientation",
        type       => 'direction',
        definition => " label='yx-orientation' opened=true ",
        cb_read    => sub { $direction_yz },
        cb_write   => sub {
            $direction_yz = shift;
            $direction_yz->[0] = 0;
            $direction_yz = Vector->new(values => $direction_yz)->normalize->values;

            my $yz_axis = Vector->new(values => [0, $direction_yz->[1], $direction_yz->[2]]);
            $yz_angle = $yz_axis->is_zero
                ? 0
                : do {
                    my $yz_angle = $yz_start->angle_with($yz_axis);
                    my $yz_sign = Vector->new(values => [1, 0, 0])->scalar_multiplication($yz_start * $yz_axis);
                    $yz_sign = ($yz_sign < 0) ? -1 : ($yz_sign > 0) ? 1 : 0;
                    $yz_angle *= $yz_sign;
                }
                ;

            if ($self->main_object) {
                $self->main_object->rotate(0, rad2deg $yz_angle);
            }
        }
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "zy-angle",
        type       => 'number',
        cb_read    => sub { rad2deg $yz_angle },
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
