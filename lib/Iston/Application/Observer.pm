package Iston::Application::Observer;
$Iston::Application::Observer::VERSION = '0.07';
use 5.12.0;

use Moo;
use OpenGL qw(:all);
use Path::Tiny;
use SDL;
use SDL::Events;
use SDL::Mouse;
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Triangle/;
use aliased qw/Iston::Vertex/;

with('Iston::Application');

has started_at     => (is => 'ro', default => sub { [gettimeofday]} );
has object_path    => (is => 'ro', required => 1);
has main_object    => (is => 'rw');
has _commands      => (is => 'lazy');

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->settings_bar->set_bar_params(visible => 'false');

    # disable mouse pointer and put it in the center of app
    SDL::Mouse::show_cursor(SDL_DISABLE);
    my ($x, $y) = ($self->width/2, $self->height/2);
    SDL::Mouse::warp_mouse($x, $y);
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
        'terminate_program'    => sub { $self->_exit },
    };
    return $commands;
}

sub process_event {
    my ($self, $event) = @_;
    # say "processing event...";
    my $action;
    if ($event->type == SDL_KEYUP) {
        my $s1 = SDLK_F1;
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

            SDLK_PLUS,  'move_camera_forward',
            SDLK_MINUS, 'move_camera_backward',
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

        my $barrier = 30;
        my $reset_position = 0;
        ($reset_position, $x) = (1, $self->width/2)
            if ($x < $barrier or $self->width - $x < $barrier);
        ($reset_position, $y) = (1, $self->height/2)
            if ($y < $barrier or $self->height -$y < $barrier);
        if ($reset_position) {
            return SDL::Mouse::warp_mouse($self->width/2 , $self->height/2 );
        };

        my ($dX, $dY) = map {$event->$_} qw/motion_xrel motion_yrel/;
        # say "x = $x, y = $y, dX = $dX, dY = $dY";
        $action = sub {
            my @rotations = ($dY, $dX);
            for my $axis (0 .. @rotations-1) {
                my $value = $self->main_object->rotate($axis);
                $value += $rotations[$axis];
                $value %= 360;
                $self->main_object->rotate($axis, $value);
            }
        };
    }
    elsif ($event->type == SDL_MOUSEBUTTONDOWN) {
        my $button = $event->button_button;
        if ($button == SDL_BUTTON_WHEELDOWN || $button == SDL_BUTTON_WHEELUP) {
            # say "mouse wheel?";
            my $step = 0.1 * ( ($button == SDL_BUTTON_WHEELUP) ? 1: -1);
            $self->camera_position->[2] += $step;
            $self->_update_view;
        }
    }
    if ($action) {
        $action->();
        $self->_log_state;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Application::Observer

=head1 VERSION

version 0.07

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
