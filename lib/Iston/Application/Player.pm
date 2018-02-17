package Iston::Application::Player;

use 5.12.0;

use Moo;
use OpenGL qw(:all);
use Path::Tiny;
use SDL;
use SDL::Events;
use SDL::Mouse;
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::History/;
use aliased qw/Iston::Vector/;

with('Iston::Application');

has object_path             => (is => 'ro', required => 1);
has history_path            => (is => 'ro', required => 1);
has main_object             => (is => 'rw');
has _commands               => (is => 'lazy');
has timer                   => (is => 'rw');
has active_record_idx       => (is => 'rw');
has step_function           => (is => 'rw');
has step_end_function       => (is => 'rw');

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

    my $history = History->new( path => $self->history_path)->load;
    $self->history($history);

};

sub objects {
    my $self = shift;
    return [$self->main_object];
}


sub _exit {
    my $self = shift;
    say "...exiting from player";
    $self->sdl_app->stop;
}

sub _build__commands {
    my $self = shift;
    my $commands = {
        'terminate_program'    => sub { $self->_exit },
    };
    return $commands;
}

sub start_replay {
    my $self = shift;
    my ($last_time, $record, $sleep_time, $history_object);
    my $initialize = sub {
        $last_time = 0;
        $self->active_record_idx(0);
        $record = $self->history->records->[$self->active_record_idx];
        $sleep_time = $record->timestamp - $last_time;
        $history_object = $self->history;
    };
    $initialize->();
    my $renew_timer_funciton;
    my $step_end_function = sub {
        if ($record) {
            $sleep_time = $record->timestamp - $last_time;
            $renew_timer_funciton->();
        } else {
            $self->_exit;
        }
    };
    $self->step_end_function($step_end_function);
    my $step = sub {
        return if($history_object != $self->history or !defined($record));
        $self->_rotate_active;
        $last_time = $record->timestamp;
        my $idx = $self->active_record_idx;
        $record = $self->history->records->[++$idx];
        $idx-- unless($record);
        $self->active_record_idx($idx);
        $self->step_end_function->();
    };
    $self->step_function($step);
    $renew_timer_funciton = sub {
        my $delay = $sleep_time;
        my $t; $t = AE::timer $delay, 0, sub {
            $self->step_function->();
        };
        $self->timer($t);
    };
    $renew_timer_funciton->();
}

sub _rotate_active {
    my $self = shift;
    my $idx = $self->active_record_idx;
    my $record = $self->history->records->[$idx];
    $self->_rotate_objects($idx);
    $self->redraw_world;
}

sub _rotate_objects {
    my ($self, $idx) = @_;
    my $record = $self->history->records->[$idx];
    my ($x_axis_degree, $y_axis_degree) = map { $record->$_ }
        qw/x_axis_degree y_axis_degree/;
    for (@{ $self->objects }) {
        $_->rotate(0, $x_axis_degree);
        $_->rotate(1, $y_axis_degree);
    }
    my $position = [ map { $record->$_ } map{ "camera_${_}" } qw/x y z/ ];
    $self->camera_position(Vector->new(values => $position));
}

sub process_event {
    my ($self, $event) = @_;
    # say "processing event...";
    my $action;
    if ($event->type == SDL_KEYUP) {
        my $dispatch_table = {
            SDLK_F4,    'terminate_program',
        };
        my $key_sym = $event->key_sym;
        my $command = $dispatch_table->{$key_sym};
        $action = $self->_commands->{$command} if defined $command;
    }
    elsif ($event->type == SDL_QUIT) {
        $action = $self->_commands->{'terminate_program'};
    }
    if ($action) {
        $action->();
    }
}

1;
