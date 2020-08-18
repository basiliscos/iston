package Iston::Application::HTMViewer;

use 5.12.0;

use Function::Parameters qw(:strict);
use Iston::Matrix;
use Iston::Utils qw/rotation_matrix/;
use JSON::XS;
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
use aliased qw/Iston::Object::HTM/;

with('Iston::Application');

has models_path    => (is => 'ro', required => 1);
has model_file     => (is => 'rw');
has main_object    => (is => 'rw');
has htm            => (is => 'lazy');
has _commands      => (is => 'lazy');
has _current_zone  => (is => 'rw', default => sub { -1 });

has xz_angle       => (is => 'rw', default => sub { 0 });
has yz_angle       => (is => 'rw', default => sub { 0 });

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->_build_menu;
};

sub _build_htm {
    my $self = shift;
    my $htm = HTM->new;
    my $r = Vector->new(values => $htm->triangles->[0]->vertices->[0]->values)->length;
    my $scale_to = 1/($r/$self->max_boundary);
    $htm->scale($scale_to);
    $htm->level(0);
    $htm->shader($self->shader_for->{object});
    $htm->notifyer($self->_notifyer);
    $htm->enabled(1);
    $htm->lighting(1);
    return $htm;
}

sub objects {
    my $self = shift;
    return [
        ($self->main_object ? ($self->main_object) : ()),
        $self->htm,
    ];
}

sub _load_model {
    my ($self, $model_path) = @_;
    say "loading $model_path";
    my $object = $self->load_object($model_path);

    $self->model_file($model_path->basename);
    $self->main_object($object);
    $self->settings_bar->refresh;
}

method _load_texture($name) {
    $self->htm->load($name);
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
        
    $bar->add_variable(
        mode       => 'rw',
        name       => "vis_htm",
        type       => 'bool',
        cb_read    => sub {
            my $object = $self->htm;
            return $object && $object->enabled;
        },
        cb_write   => sub {
            my $object = $self->htm;
            $object->enabled(shift) if $object;
        },
        definition => {
            label => 'HTM',
            key   => 'h',
        },
    );

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

    my @texture_names = ("choose texture", sort grep { /texture.json$/ }  map { $_->basename }  path(".")->children);
    my $texture_type = Type->new("available_textures", \@texture_names);
    my $texture_index = 0;
    $bar->add_variable(
        mode       => 'rw',
        name       => "texture",
        type       => $texture_type,
        cb_read    => sub { $texture_index },
        cb_write   => sub {
            $texture_index = shift;
            return if $texture_index == 0; # skip "choose texture" index;
            $self->_load_texture($texture_names[$texture_index]);
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
        name       => "current_zone",
        type       => 'number',
        cb_read    => sub { $self->_current_zone + 1 },
    );
}

around _drawGLScene => sub {
    my $orig = shift;
    my $self = shift;
    $orig->($self, 0);

    my $distance = 0.1;
    glColor3f(1.0, 0.0, 0.0);
    glBegin(GL_LINES);
      glVertex2f(-$distance, 0.0);
      glVertex2f(+$distance, 0.0);
    glEnd();
    glBegin(GL_LINES);
      glVertex2f(0, -$distance);
      glVertex2f(0, +$distance);
    glEnd();
    glFlush;
};

sub _build__commands {
    my ($self) = @_;
    my $commands = {
        'add_zone'          => sub { $self->_add_zone;      },
        'remove_zone'       => sub { $self->_remove_zone;   },
        'activate_next'     => sub { $self->_activate_next; },
        'activate_prev'     => sub { $self->_activate_prev; },
        'enlarge_zone'      => sub { $self->_enlarge_zone;  },
        'shrink_zone'       => sub { $self->_shrink_zone;   },
        'terminate_program' => sub { $self->sdl_app->stop   },
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
            SDLK_F12()       => 'remove_zone',
            SDLK_LEFT()      => 'activate_prev',
            SDLK_RIGHT()     => 'activate_next',
            SDLK_UP()        => 'enlarge_zone',
            SDLK_DOWN()      => 'shrink_zone',
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
