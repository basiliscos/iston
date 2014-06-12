package Iston::Application::Analyzer;

use 5.12.0;

use AnyEvent;
use Moo;
use OpenGL qw(:all);
use Path::Tiny;

use aliased qw/Iston::History/;
use aliased qw/Iston::Object::HTM/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Vertex/;

with('Iston::Application');

has main_object       => (is => 'rw');
has models_path       => (is => 'ro', required => 1);
has htm               => (is => 'lazy');
has observation_path  => (is => 'rw');
has time_ratio        => (is => 'rw', default => sub { 1 });
has timer             => (is => 'rw');
has step_function     => (is => 'rw');
has step_end_function => (is => 'rw');

sub _build_menu;

sub BUILD {
    my $self = shift;
    $self->init_app;
    glutSetCursor(GLUT_CURSOR_INHERIT);
    $self->_build_menu;
}

sub _build_htm {
    my $self = shift;
    my $htm = HTM->new;
    # $htm->mode('mesh');
    my $r = Vertex->new([0, 0, 0])->vector_to($htm->triangles->[0]->vertices->[0])->length;
    my $scale_to = 1/($r/$self->max_boundary);
    $htm->scale($scale_to); # 2.5
    $htm->level(3);
    return $htm;
}

sub objects {
    my $self = shift;
    [map { $_ ? $_ : () } ($self->main_object, $self->htm, $self->observation_path) ];
}

sub _load_object {
    my ($self, $object_path, $history_path) = @_;
    my $object = $self->load_object($object_path);
    $self->main_object($object);
    my $history = History->new( path => $history_path)->load;
    $self->history($history);

    my $r1 = ($object->radius) * $object->scale;
    my $r2 = $self->htm->radius;
    my $scale_to = $r1/$r2;
    $self->htm->scale($scale_to*1.01);
    my $observation_path = ObservationPath->new(history => $history);
    $observation_path->scale($scale_to*1.01);
    $self->observation_path($observation_path);

    my $projections = $self->htm->find_projections($observation_path);
    $self->htm->apply_projections($projections);
    $self->htm->calculate_observation_timings($projections, $observation_path);

    my $analisys_path = "${history_path}-analisys.txt";
    open my $analisys_fh, ">:encoding(utf8)", $analisys_path
        or die "Can't open $analisys_path : $!";
    $self->_dump_analisys($projections, $analisys_fh);

    $self->_start_replay;
}

sub _dump_analisys {
    my ($self, $projections, $output_fh) = @_;
    my $root_list = $self->htm->levels_cache->{0};
    my $info = [];
    $self->htm->walk_projections($projections, sub {
        my ($vertex_index, $level, $path) = @_;
        $path->apply($root_list, sub {
            my ($triangle, $path) = @_;
            my $total_time = $triangle->payload->{total_time};
            $info->[$level]->{$path} = $total_time;
        });
    });

    say $output_fh "total time per level and per triangle path in seconds";
    for my $level (0 .. @$info - 1) {
        say $output_fh "==================";
        say $output_fh "level: $level";
        say $output_fh "==================\n";
        my @paths = sort { $a cmp $b } keys %{ $info->[$level] };
        for my $path (@paths) {
            say $output_fh "$path = ", $info->[$level]->{$path};
        }
        say $output_fh "\n";
    }
}

sub _build_menu {
    my $self = shift;

    # submenus for loading objects
    my @models =
        map  { { path => $_ }}
        sort { $a cmp $b }
        grep { /\.obj$/i }
        path($self->models_path)->children;
    my %history_of = map { $_->{path}->basename => $_ }
        @models;

    my @histories =  grep { /\.csv/i } path(".")->children;
    for my $h (@histories) {
        if($h->basename =~ /^history_(\d+)_(.+)\.csv$/) {
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
            $self->_load_object($me->{path}, $histories->[$history_idx]);
        };
        my $submenu_id = glutCreateMenu($menu_handler);
        for my $h_idx (0 .. @$histories - 1 ){
            my $h_name = $histories->[$h_idx];
            glutAddMenuEntry($h_name->basename, $h_idx);
        }
        push @submenus, { id => $submenu_id, name => $name};
    }
    if(@submenus) {
        my $load_submenu = glutCreateMenu($menu_callback);
        for (@submenus) {
            glutAddSubMenu($_->{name}, $_->{id});
        }
        @submenus = ({ id => $load_submenu, name => "load object" });
    }

    # create turn on/off objects menu
    {
        my @items = (
            main_object      => 'Object',
            htm              => 'Hierarchical Triangular Mesh',
            observation_path => 'Observation path',
        );
        my $visibility_handler = sub {
            my $idx = shift;
            my $object_name = $items[$idx];
            my $object = $self->$object_name;
            return unless $object;
            my $state = $object->enabled;
            $object->enabled(!$state);
        };
        my $visibility_submenu = glutCreateMenu($visibility_handler);
        for my $idx (0 .. @items/2-1){
            my $object_name = $items[$idx*2];
            my $label       = $items[$idx*2 + 1];
            glutAddMenuEntry($label, $idx*2);
        }
        push @submenus, ({ id => $visibility_submenu, name => "visibility" });
    }

    my $menu_id = glutCreateMenu($menu_callback);
    for (@submenus) {
        glutAddSubMenu($_->{name}, $_->{id});
        say "added ", $_->{name};
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
    my $renew_timer_funciton;
    my $step_end_function = sub {
        if ($record) {
            $sleep_time = $record->timestamp - $last_time;
            $renew_timer_funciton->();
        } else {
            my $pause; $pause = AE::timer 3, 0, sub {
                undef $pause;
                $self->_start_replay;
            }
        }
    };
    $self->step_end_function($step_end_function);
    my $step = sub {
        return if($history_object != $self->history or !defined($record));
        my ($x_axis_degree, $y_axis_degree) = map { $record->$_ }
            qw/x_axis_degree y_axis_degree/;
        for (@{ $self->objects }) {
            $_->rotate(0, $x_axis_degree);
            $_->rotate(1, $y_axis_degree);
        }
        $self->camera_position([
            map { $record->$_ } qw/camera_x camera_y camera_z/
        ]);
        $self->observation_path->active_time($record->timestamp);
        $self->refresh_world();

        $last_time = $record->timestamp;
        $record = $self->history->records->[++$i];
        $self->step_end_function->();
    };
    $self->step_function($step);
    $renew_timer_funciton = sub {
        # timer = 0 check, i.e. stop replay has been pressed
        return if(defined($self->timer) && $self->timer == 0);
        my $t; $t = AE::timer $sleep_time * $self->time_ratio, 0, sub {
            $self->step_function->();
        };
        $self->timer($t);
    };
    $renew_timer_funciton->();
}

sub key_pressed {
    my ($self, $key) = @_;

    my $rotate_step = 2;
    my $rotation = sub {
        my ($axis, $step) = @_;
        my $subject = $self->htm;
        return sub {
            my $value = $subject->rotate($axis);
            $value += $step;
            $value %= 360;
            $subject->rotate($axis, $value);
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
    my $pause_unpause = sub {
        if($self->timer) {
            $self->timer(0);
        }else {
            $self->timer(1);
            $self->step_end_function->();
        }
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
        ' ' => $pause_unpause,
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
