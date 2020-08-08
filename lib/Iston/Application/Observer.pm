package Iston::Application::Observer;

use 5.12.0;

use JSON::XS;
use Moo;
use OpenGL qw(:all);
use Path::Tiny;
use SDL;
use SDL::Events;
use SDL::Mouse;
use SDL::Surface;
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Triangle/;
use aliased qw/Iston::Vertex/;

with('Iston::Application');

has started_at     => (is => 'ro', default => sub { [gettimeofday]} );
has object_path    => (is => 'ro', required => 1);
has main_object    => (is => 'rw');
has _commands      => (is => 'lazy');
has mouse          => (is => 'rw', default => sub { 0; });

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->settings_bar->set_bar_params(visible => 'false');

    # disable mouse pointer and put it in the center of app
    SDL::Mouse::show_cursor(SDL_DISABLE);
    my ($x, $y) = ($self->width/2, $self->height/2);
    SDL::Mouse::warp_mouse($x, $y);
    my $object = $self->load_object($self->object_path);
    $object->rotate(0, $ENV{ISTON_ROTATE_Y} // 0);
    $object->rotate(1, $ENV{ISTON_ROTATE_X} // 0);

    $self->main_object($object);
    push @{ $self->objects }, $object;

    $self->_log_state;
};

sub objects {
    my $self = shift;
    return [$self->main_object];
}

sub _log_state {
    my ($self, $label) = @_;

    return unless $self->history;
    my $camera_position = $self->camera_position->values;
    my $record = Record->new(
        timestamp     => tv_interval ( $self->started_at, [gettimeofday]),
        x_axis_degree => $self->main_object->rotate(0),
        y_axis_degree => $self->main_object->rotate(1),
        camera_x      => $camera_position->[0],
        camera_y      => $camera_position->[1],
        camera_z      => $camera_position->[2],
        label         => $label,
    );
    push @{ $self->history->records }, $record;
}

sub _exit {
    my $self = shift;
    say "...exiting from observer";
    $self->_log_state;
    if($self->history) {
        my $history_path = $self->history->path;
        my $analisys_dir = path("${history_path}-analysis");
        my $config_path = path("$analisys_dir/meta.json");
        my $config = {
            ISTON_MOUSE_SENSIVITY => get_sensivity(),
            ISTON_ROTATE_Y        => $ENV{ISTON_ROTATE_Y} // 0,
            ISTON_ROTATE_X        => $ENV{ISTON_ROTATE_X} // 0,
        };
        $config_path->spew(JSON::XS->new->pretty->encode($config));
        $self->history->save;
    }
    $self->sdl_app->stop;
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
            return;
        }
    };
    my $camera_z_move = sub {
        my $value = shift;
        return sub {
            $self->camera_position->values->[2] += $value;
            $self->_update_view;
            return;
        };
    };

    my $object = $self->main_object;
    my ($w, $h) = ($self->width, $self->height);

    my $analisys_dir;
    if ($self->history) {
        my $history_path = $self->history->path;
        $analisys_dir = path("${history_path}-analysis");
        $analisys_dir->mkpath;
    }

    my $press = sub { my $label = shift;
        return sub {
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            $object->draw_function->();
            if ($analisys_dir) {
                my $image = SDL::Surface->new(
                    SDL_SWSURFACE, $w, $h, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000,
                );
                my $pix_buffer = $image->get_pixels_ptr;
                glReadPixels_s(0, 0, $w, $h, GL_RGBA, GL_UNSIGNED_BYTE, $pix_buffer);
                SDL::Video::save_BMP( $image, "$analisys_dir/$label.bmp" );
            }
            $self->sdl_app->sync;
            return $label;
        }
    };

    my $toggle_mouse = sub {
        my $val = !$self->mouse();
        $self->mouse($val);
        if (!$val) {
            my ($x, $y) = ($self->width/2, $self->height/2);
            SDL::Mouse::warp_mouse($x, $y);
        }
        SDL::Mouse::show_cursor($val ? SDL_ENABLE : SDL_DISABLE);
    };

    my $rotate_step = 2;
    my $commands = {
        'press_1'     => $press->('1'),
        'press_2'     => $press->('2'),
        'press_3'     => $press->('3'),
        'press_4'     => $press->('4'),
        'press_5'     => $press->('5'),
        'press_6'     => $press->('6'),
        'press_7'     => $press->('7'),
        'press_8'     => $press->('8'),
        'press_9'     => $press->('9'),
        'press_0'     => $press->('0'),
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
        'toggle_mouse'         => $toggle_mouse,
        'terminate_program'    => sub { $self->_exit; return },
    };
    return $commands;
}

sub process_event {
    my ($self, $event) = @_;
    # say "processing event...";
    my $action;
    if ($event->type == SDL_KEYUP) {
        my $dispatch_table = {
            SDLK_w,     'rotate_N',
            SDLK_s,     'rotate_S',
            SDLK_a,     'rotate_W',
            SDLK_d,     'rotate_E',

            SDLK_UP,    'rotate_N',
            SDLK_DOWN,  'rotate_S',
            SDLK_LEFT,  'rotate_W',
            SDLK_RIGHT, 'rotate_E',

            SDLK_KP8,   'rotate_N',
            SDLK_KP2,   'rotate_S',
            SDLK_KP4,   'rotate_W',
            SDLK_KP6,   'rotate_E',
            SDLK_KP7,   'rotate_NW',
            SDLK_KP9,   'rotate_NE',
            SDLK_KP3,   'rotate_SE',
            SDLK_KP1,   'rotate_SW',

            SDLK_1,     'press_1',
            SDLK_2,     'press_2',
            SDLK_3,     'press_3',
            SDLK_4,     'press_4',
            SDLK_5,     'press_5',
            SDLK_6,     'press_6',
            SDLK_7,     'press_7',
            SDLK_8,     'press_8',
            SDLK_9,     'press_9',
            SDLK_0,     'press_0',

            SDLK_PLUS,      'move_camera_forward',
            SDLK_MINUS,     'move_camera_backward',
            SDLK_KP_PLUS,   'move_camera_forward',
            SDLK_KP_MINUS,  'move_camera_backward',
            SDLK_ESCAPE,    'toggle_mouse',

            SDLK_F4,    'terminate_program',
        };
        my $key_sym = $event->key_sym;
        my $command = $dispatch_table->{$key_sym};
        $action = $self->_commands->{$command} if defined $command;
    }
    elsif ($event->type == SDL_QUIT) {
        $action = $self->_commands->{'terminate_program'};
    }
    elsif ($event->type == SDL_MOUSEMOTION) {
        my ($x, $y) = map {$event->$_} qw/motion_x motion_y/;
        my $warp_event = $x == $self->width/2 && $y == $self->height/2;
        return if $warp_event;

        my $mouse_sense = $ENV{ISTON_MOUSE_SENSIVITY} // 5;
        my $barrier = $ENV{ISTON_MOUSE_BARRIER} // 30;
        if (!$self->mouse) {
            if (abs($x  - $self->width/2) > 30 || abs($y - $self->height/2) > 30) {
                return SDL::Mouse::warp_mouse($self->width/2 , $self->height/2);
            }

            my ($dX, $dY) = map {$event->$_ * $mouse_sense } qw/motion_xrel motion_yrel/;
            $action = sub {
                my @rotations = ($dY, $dX);
                for my $axis (0 .. @rotations-1) {
                    my $value = $self->main_object->rotate($axis);
                    $value += $rotations[$axis];
                    $value -= 360 if $value >= 360;
                    #$value %= 360;
                    $self->main_object->rotate($axis, $value);
                }
                return;
            };
        }
    }
    elsif ($event->type == SDL_MOUSEBUTTONDOWN) {
        my $button = $event->button_button;
        if ($button == SDL_BUTTON_WHEELDOWN || $button == SDL_BUTTON_WHEELUP) {
            # say "mouse wheel?";
            my $z_sensivity = $ENV{ISTON_Z_SENTIVITY} // 0.1;
            my $step = $z_sensivity * ( ($button == SDL_BUTTON_WHEELUP) ? 1: -1);
            $self->camera_position->values->[2] += $step;
            $self->_update_view;
        }
    }

    if ($action) {
        my $label = $action->();
        $self->_log_state($label);
    }
}

sub get_sensivity  {
    $ENV{ISTON_MOUSE_SENSIVITY} // 5;
}

1;
