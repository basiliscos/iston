package Iston::Application::Analyzer;

use 5.12.0;

use AnyEvent;
use Moo;
use OpenGL qw(:all);
use Path::Tiny;

use aliased qw/Iston::History/;
use aliased qw/Iston::Object::Octahedron/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Vertex/;

with('Iston::Application');

has main_object      => (is => 'rw');
has models_path      => (is => 'ro', required => 1);
has htm              => (is => 'lazy');
has observation_path => (is => 'rw');
has time_ratio       => (is => 'rw', default => sub { 1 });

sub _build_menu;

sub BUILD {
    my $self = shift;
    $self->init_app;
    $self->_build_menu;
}

sub _build_htm {
    my $self = shift;
    my $htm = Octahedron->new;
    $htm->mode('mesh');
    my $r = Vertex->new([0, 0, 0])->vector_to($htm->vertices->[0])->length;
    my $scale_to = 1/($r/$self->max_boundary);
    $htm->scale($scale_to); # 2.5
    $htm->level(3);
    return $htm;
}

sub objects {
    my $self = shift;
    [map { $_ ? $_ : () } ($self->main_object, $self->htm, $self->observation_path) ];
}

sub _build_menu {
    my $self = shift;
    my @models =
        map  { { path => $_ }}
        sort { $a cmp $b }
        grep { /\.obj$/i }
        path($self->models_path)->children;
    my %history_of = map { $_->{path}->basename => $_ }
        @models;

    my @histories =  grep { /\.csv/i } path(".")->children;
    for my $h (@histories) {
        if($h->basename =~ /history_(\d+)_(.+)\.csv/) {
            my $model_name = $2;
            if ( exists $history_of{$model_name} ) {
                push @{ $history_of{$model_name}->{histories} }, $h;
            }
        }
    };
    @models = grep { exists $history_of{$_->{path}->basename}->{histories} } @models;
    for (@models) {
        $_->{histories} = [
            sort {$a cmp $b}
            @{ $history_of{$_->{path}->basename}->{histories} }
        ];
    }

    my $menu_callback = sub {
        my $menu_id = shift;
        say "clicked on:", $menu_id;
    };

    my @submenus;
    for my $idx (0 .. @models-1) {
        my $me = $models[$idx];
        my $name = $me->{path}->basename;
        my $histories = $me->{histories};
        my $menu_handler = sub {
            my $history_idx = shift;
            my $object = $self->load_object($me->{path});
            $self->main_object($object);
            my $history_path = $histories->[$history_idx];
            my $history = History->new( path => $history_path)->load;
            $self->history($history);

            my $r1 = ($object->radius) * $object->scale;
            my $r2 = $self->htm->radius;
            my $scale_to = $r1/$r2;
            $self->htm->scale($scale_to*1.01);
            my $observation_path = ObservationPath->new(history => $history);
            $observation_path->scale($scale_to*1.01);
            $self->observation_path($observation_path);
            $self->_start_replay;
        };
        my $submenu_id = glutCreateMenu($menu_handler);
        for my $h_idx (0 .. @$histories - 1 ){
            my $h_name = $histories->[$h_idx];
            glutAddMenuEntry($h_name->basename, $h_idx);
        }
        push @submenus, { id => $submenu_id, name => $name};
    }
    my $menu_id = glutCreateMenu($menu_callback);
    for (@submenus) {
        glutAddSubMenu($_->{name}, $_->{id});
    }
    glutAttachMenu(GLUT_RIGHT_BUTTON) if(@submenus);
}

sub _exit {
    my $self = shift;
    say "...exiting from analyzer";
    $self->cv_finish->send;
}

sub _start_replay {
    my $self = shift;
    my ($last_time, $i, $record, $sleep_time, $history_object);
    my $initialize = sub {
        $last_time = $i = 0;
        $record = $self->history->records->[$i];
        $sleep_time = $record->timestamp - $last_time;
        $history_object = $self->history;
    };
    $initialize->();
    my $step; $step = sub {
        my $t; $t = AE::timer $sleep_time * $self->time_ratio, 0, sub {
            undef $t;
            return if($history_object != $self->history);

            my ($x_axis_degree, $y_axis_degree) = map { $record->$_ }
                qw/x_axis_degree y_axis_degree/;
            for (@{ $self->objects }) {
                $_->rotation->[0] = $x_axis_degree;
                $_->rotation->[1] = $y_axis_degree;
            }
            $self->camera_position([
                map { $record->$_ } qw/camera_x camera_y camera_z/
            ]);
            $self->observation_path->active_time($record->timestamp);
            $self->refresh_world();

            $last_time = $record->timestamp;
            $record = $self->history->records->[++$i];
            if($record) {
                $sleep_time = $record->timestamp - $last_time;
                $step->();
            } else {
                my $pause; $pause = AE::timer 3, 0, sub {
                    undef $pause;
                    $self->_start_replay;
                }
            }
        }
    };
    $step->();
}

sub key_pressed {
    my ($self, $key) = @_;

    my $rotate_step = 2;
    my $rotation = sub {
        my ($c, $step) = @_;
        my $subject = $self->htm;
        return sub {
            $subject->rotation->[$c] += $step;
            $subject->rotation->[$c] %= 360;
        }
    };
    my $adjust_time_ration = sub {
        my $value = shift;
        return sub {
            $self->time_ratio( $self->time_ratio * $value );
        };
    };
    my $switch_mode = sub {
        my $subject = $self->main_object // $self->htm;
        my $new_mode = $subject->mode eq 'normal'
            ? 'mesh'
            : 'normal';
        $subject->mode($new_mode);
    };
    my $detalize = sub {
        my $level_delta = shift;
        return sub {
            my $level = $self->htm->level;
            $self->htm->level($level + $level_delta);
        };
    };
    my $dispatch_table = {
        'w' => $rotation->(0, -$rotate_step),
        's' => $rotation->(0, $rotate_step),
        'a' => $rotation->(1, -$rotate_step),
        'd' => $rotation->(1, $rotate_step),
        '+' => $adjust_time_ration->(1.1),
        '-' => $adjust_time_ration->(0.95),
        'i' => $detalize->(1),
        'I' => $detalize->(-1),
        'm' => $switch_mode,
        'q' => sub {
            my $m = glutGetModifiers;
            $self->_exit if($m & GLUT_ACTIVE_ALT);
        },
    };
    my $key_char = chr($key);
    my $action = $dispatch_table->{$key_char};
    $action->() if($action);
};

sub mouse_movement {
}

sub mouse_click {
}

1;
