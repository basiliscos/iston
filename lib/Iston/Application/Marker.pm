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
use aliased qw/Iston::Zone/;
use aliased qw/Iston::Object::MarkerContainer/;

with('Iston::Application');

has models_path    => (is => 'ro', required => 1);
has main_object    => (is => 'rw');
has _commands      => (is => 'lazy');
has _markers       => (is => 'lazy');
has _current_zone  => (is => 'rw', default => sub { -1 });

has xz_angle       => (is => 'rw', default => sub { 0 });
has yz_angle       => (is => 'rw', default => sub { 0 });

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->_build_menu;
};

sub _build__markers {
    my ($self) = @_;
    my $mc = MarkerContainer->new(
        shader => $self->shader_for->{object},
    );
    $mc->scale($self->max_boundary + 0.1);
    return $mc;
}

sub objects {
    my $self = shift;
    return [ $self->_markers, ($self->main_object ? ($self->main_object) : ()) ];
}

sub _load_model {
    my ($self, $model_path) = @_;
    say "loading $model_path";
    my $object = $self->load_object($model_path);

    # my $r1 = ($object->radius) * $object->scale;
    # my $r2 = $self->max_boundary;
    # my $scale_to = $r1/$r2;
    # $object->scale($scale_to);
    # $object->clear_draw_function;
    $self->main_object($object);
    $self->settings_bar->refresh;
}

sub _rotate {
    my ($self, $xz, $yz) = @_;
    for (@{ $self->objects }) {
        $_->rotate(1, $xz);
        $_->rotate(0, $yz);
    }
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

    my $rotate_objects = sub {
        $self->_rotate($self->xz_angle, $self->yz_angle);
        $self->settings_bar->refresh;
    };

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
            my $xz_angle = $xz_axis->is_zero
                ? 0
                : do {
                    my $xz_angle = $xz_start->angle_with($xz_axis);
                    my $xz_sign = Vector->new(values => [0, 1, 0])->scalar_multiplication($xz_start * $xz_axis);
                    $xz_sign = ($xz_sign < 0) ? -1 : ($xz_sign > 0) ? 1 : 0;
                    $xz_angle *= $xz_sign;
                };
            $xz_angle = rad2deg $xz_angle;
            $self->xz_angle($xz_angle);
            $rotate_objects->();
        }
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "zx-angle",
        type       => 'number',
        cb_read    => sub { $self->xz_angle },
    );

    my $direction_yz = [0.0, 0.0, 1.0];
    my $initial_direction_yz = [0.0, 0.0, 1.0];
    my $yz_start = Vector->new(values => [$initial_direction_yz->[0], 0, $initial_direction_yz->[2]]);

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
            my $yz_angle = $yz_axis->is_zero
                ? 0
                : do {
                    my $yz_angle = $yz_start->angle_with($yz_axis);
                    my $yz_sign = Vector->new(values => [1, 0, 0])->scalar_multiplication($yz_start * $yz_axis);
                    $yz_sign = ($yz_sign < 0) ? -1 : ($yz_sign > 0) ? 1 : 0;
                    $yz_angle *= $yz_sign;
                }
                ;
            $yz_angle = rad2deg $yz_angle;
            $self->yz_angle($yz_angle);
            $rotate_objects->();
        }
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "zy-angle",
        type       => 'number',
        cb_read    => sub { $self->yz_angle },
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "zones",
        type       => 'number',
        cb_read    => sub { scalar(@{ $self->_markers->zones }) },
    );
    $bar->add_variable(
        mode       => 'ro',
        name       => "current_zone",
        type       => 'number',
        cb_read    => sub { $self->_current_zone + 1 },
    );
}

sub _add_zone {
    my ($self) = @_;
    my $mc = $self->_markers;
    push @{ $mc->zones }, Zone->new(
        xz => -1 * $self->xz_angle,
        yz => -1 * $self->yz_angle,
        spread => 10,
        active => 1,
    );
    if ($self->_current_zone >= 0) {
        $mc->zones->[$self->_current_zone]->active(0);
    }
    $self->_current_zone( @{ $mc->zones } - 1 );
    $self->settings_bar->refresh;
    $mc->clear_draw_function;
}

sub _remove_zone {
    my ($self) = @_;
    my $idx = $self->_current_zone;
    return unless $idx >= 0;
    my $mc = $self->_markers;
    splice @{ $mc->zones }, $idx, 1;
    $idx--;
    $idx = 0 if ($idx < 0 && @{ $mc->zones });
    $self->_current_zone($idx);
    $self->settings_bar->refresh;
    $mc->clear_draw_function;
}

sub _activate_prev {
    my ($self) = @_;
    my $idx = $self->_current_zone;
    my $mc = $self->_markers;
    my $total = @{ $mc->zones };
    return unless $idx >= 0;

    $mc->zones->[$idx]->active(0);
    $idx--;
    $idx = $total - 1 if ($idx < 0);
    $self->_current_zone($idx);
    $mc->zones->[$idx]->active(1);
    $self->settings_bar->refresh;
    $mc->clear_draw_function;
}

sub _activate_next {
    my ($self) = @_;
    my $idx = $self->_current_zone;
    my $mc = $self->_markers;
    my $total = @{ $mc->zones };
    return unless $idx >= 0;

    $mc->zones->[$idx]->active(0);
    $idx++;
    $idx %= $total;
    $self->_current_zone($idx);
    $mc->zones->[$idx]->active(1);
    $self->settings_bar->refresh;
    $mc->clear_draw_function;
}


sub _build__commands {
    my ($self) = @_;
    my $commands = {
        'add_zone'          => sub { $self->_add_zone; },
        'remove_zone'       => sub { $self->_remove_zone; },
        'activate_next'     => sub { $self->_activate_next; },
        'activate_prev'     => sub { $self->_activate_prev; },
        'terminate_program' => sub { $self->sdl_app->stop },
    };
    return $commands;
}

sub process_event {
    my ($self, $event) = @_;
    # say "processing event...";
    my $action;
    AntTweakBar::eventSDL($event);
    if ($event->type == SDL_KEYUP) {
        my $dispatch_table = {
            SDLK_SPACE()     => 'add_zone',
            SDLK_BACKSPACE() => 'remove_zone',
            SDLK_LEFT()      => 'activate_prev',
            SDLK_RIGHT()     => 'activate_next',
        };
        my $key = $event->key_sym;
        my $command = $dispatch_table->{$key};
        $action = $self->_commands->{$command} if defined $command;
    }
    if ($event->type == SDL_QUIT) {
        $action = $self->_commands->{'terminate_program'};
    }
    if ($action) {
        $action->();
    }
}

1;
