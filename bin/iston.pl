#!/usr/bin/env perl

use 5.12.0;

use AnyEvent;
use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use List::Util qw/max/;
use OpenGL qw(:all);
use Path::Tiny;
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;
use aliased qw/Iston::Loader/;
use aliased qw/Iston::Object::Octahedron/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

sub _log_state;
sub _prepare_replay;
sub _start_replay;
sub _load_object;

GetOptions(
    'o|object=s'         => \my $object_path,
    'n|no_history'       => \my $no_history,
    'r|replay_history'   => \my $replay_history,
    'm|models_path=s'    => \my $models_path,
    'h|help'             => \my $help,
);

my $show_help = $help || (!$object_path && !$replay_history)
    || ($replay_history && !defined($models_path));
die <<"EOF" if($show_help);
usage: $0 OPTIONS

     $0 [options]

These options are available:
  -o, --object         Generates pair of private an public keys and stores them
                       in the current directory
  -n, --no_history     Do not record history
  -m, --models_path    Path to directory with models
  -r  --replay_history Replay history mode
  -h, --help           Show this message.
EOF

$models_path //= '.';
my $interactive_mode = !defined($replay_history);

glutInit;
glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
glEnable(GL_DEPTH_TEST);
glEnableClientState(GL_COLOR_ARRAY);
glEnableClientState(GL_VERTEX_ARRAY);
my ($width, $height) = (800, 600);
glutInitWindowSize($width, $height);
glutCreateWindow("Iston");
glutDisplayFunc(\&drawGLScene);
glutIdleFunc(\&drawGLScene);
glutKeyboardFunc(\&keyPressed);
glClearColor(0.0, 0.0, 0.0, 0.0);
initGL($width, $height);

my $camera_position = [0, 0, -7];
my ($main_object, $htm, $observation_path);

my @other_objects;
my $max_boundary = 3.0;

my $history;
my $started_at = [gettimeofday];

if($replay_history) {
    $no_history = 1;
    _prepare_replay;
} else {
    $object_path = path($object_path);
    _load_object($object_path);
    if (!$no_history) {
        my $history_path = join('_', 'history', time, $object_path->basename ) . ".csv";
        $history = History->new(path => $history_path);
    }
    _log_state;
}

my $refresh_world = sub {
    glutMainLoopEvent;
    glutPostRedisplay;
};
my $t; $t = AE::timer 0, 0.01, sub {
    $refresh_world->();
};
AE::cv->recv;

sub init_light {

    glShadeModel (GL_SMOOTH);

    # Initialize material property, light source, lighting model,
    # and depth buffer.
    my @mat_specular = ( 1.0, 1.0, 1.0, 1.0 );
    #my @mat_diffuse  = ( 0.1, 0.4, 0.8, 1.0 );
    my @light_position = ( 20.0, 20.0, 20.0, 0.0 );

    #glMaterialfv_s(GL_FRONT, GL_DIFFUSE, pack("f4",@mat_diffuse));
    glMaterialfv_s(GL_FRONT, GL_SPECULAR, pack("f4",@mat_specular));
    glMaterialfv_s(GL_FRONT, GL_SHININESS, pack("f1", 120.0));
    glLightfv_s(GL_LIGHT0, GL_POSITION, pack("f4",@light_position));

    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
}

sub initGL {
    my ($width, $height) = @_;
    init_light;
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    gluPerspective(65.0, $width/$height, 0.1, 100.0);
    glMatrixMode(GL_MODELVIEW);
    glEnable(GL_NORMALIZE);
}

sub drawGLScene {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glLoadIdentity;
    glTranslatef(@$camera_position);

    for($main_object, @other_objects) {
        next unless $_;
        glPushMatrix;
        glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
        glPushAttrib(GL_ALL_ATTRIB_BITS);
        $_->draw;
        glPopAttrib;
        glPopClientAttrib;
        glPopMatrix;
    }

    glFlush;
    glutSwapBuffers;
    $interactive_mode && usleep(50000);
}

sub _create_menu {
    my @models =
        map  { { path => $_ }}
        sort { $a cmp $b }
        grep { /\.obj$/i }
        path($models_path)->children;
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
            _load_object($me->{path});
            my $history_path = $histories->[$history_idx];
            $history = History->new( path => $history_path)->load;

            my $r1 = ($main_object->radius) * $main_object->scale;
            my $r2 = $htm->radius;
            my $scale_to = $r1/$r2;
            $htm->scale($scale_to*1.01);
            $observation_path = ObservationPath->new(history => $history);
            $observation_path->scale($scale_to*1.01);
            @other_objects = ($htm, $observation_path);
            _start_replay;
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

sub _start_replay {
    my $time_ratio = 0.25;
    my ($last_time, $i, $record, $sleep_time, $history_object);
    my $initialize = sub {
        $last_time = $i = 0;
        $record = $history->records->[$i];
        $sleep_time = $record->timestamp - $last_time;
        $history_object = $history;
    };
    $initialize->();
    my $step; $step = sub {
        my $t; $t = AE::timer $sleep_time * $time_ratio, 0, sub {
            undef $t;
            return if($history_object != $history);

            my ($x_axis_degree, $y_axis_degree) = map { $record->$_ }
                qw/x_axis_degree y_axis_degree/;
            for ($main_object, @other_objects) {
                $_->rotation->[0] = $x_axis_degree;
                $_->rotation->[1] = $y_axis_degree;
            }
            @$camera_position = map { $record->$_ } qw/camera_x camera_y camera_z/;
            $refresh_world->();

            $last_time = $record->timestamp;
            $record = $history->records->[++$i];
            if($record) {
                $sleep_time = $record->timestamp - $last_time;
                $step->();
            } else {
                my $pause; $pause = AE::timer 3, 0, sub {
                    undef $pause;
                    _start_replay;
                }
            }
        }
    };
    $step->();
}

sub _prepare_replay {
    _create_menu;

    $htm = Octahedron->new;
    $htm->mode('mesh');
    my $r = Vertex->new([0, 0, 0])->vector_to($htm->vertices->[0])->length;
    my $scale_to = 1/($r/$max_boundary);
    $htm->scale(2.5);
    $htm->level(3);
    push @other_objects, $htm;
}

sub _log_state {
    return if $no_history;
    my $record = Record->new(
        timestamp     => tv_interval ( $started_at, [gettimeofday]),
        x_axis_degree => $main_object->rotation->[0],
        y_axis_degree => $main_object->rotation->[1],
        camera_x      => $camera_position->[0],
        camera_y      => $camera_position->[1],
        camera_z      => $camera_position->[2],
    );
    push @{ $history->records }, $record;
}

sub _exit {
    say "...exiting";
    _log_state;
    $history->save if(!$no_history);
    glutLeaveMainLoop;
    exit;
}

sub _load_object {
    my $path = shift;
    $main_object = Loader->new(file => $path)->load;

    my ($max_distance) =
        reverse sort {$a->length <=> $b->length }
        map { Vector->new( $_ ) }
        $main_object->boudaries;
    my $scale_to = 1/($max_distance->length/$max_boundary);
    $main_object->scale( $scale_to );
    say "model $path loaded, scaled: $scale_to";
}

sub keyPressed {
    my ($key, $x, $y) = @_;
    my $rotate_step = 2;
    my $rotation = sub {
        my ($c, $step) = @_;
        my $subject = $main_object // $htm;
        return sub {
            $subject->rotation->[$c] += $step;
            $subject->rotation->[$c] %= 360;
        }
    };
    my $scaling = sub {
        my $value = shift;
        my $subject = $main_object // $htm;
        return sub {
            $subject->scale($main_object->scale * $value);
        };
    };
    my $detalize = sub {
        my $level_delta = shift;
        my $subject = $htm // $main_object;
        return sub {
            if ($subject->can('level')) {
                my $level = $subject->level;
                $subject->level($level + $level_delta);
            }
        };
    };
    my $camera_z_move = sub {
        my $value = shift;
        return sub {
            $camera_position->[2] += $value;
        };
    };
    my $switch_mode = sub {
        my $subject = defined($replay_history) ? $htm : $main_object;
        my $new_mode = $subject->mode eq 'normal'
            ? 'mesh'
            : 'normal';
        $subject->mode($new_mode);
    };
    my $dispatch_table = {
        'w' => $rotation->(0, -$rotate_step),
        's' => $rotation->(0, $rotate_step),
        'a' => $rotation->(1, -$rotate_step),
        'd' => $rotation->(1, $rotate_step),
        'i' => $detalize->(1),
        'I' => $detalize->(-1),
        '+' => $camera_z_move->(0.1),
        '-' => $camera_z_move->(-0.1),
        'm' => $switch_mode,
        'q' => sub {
            my $m = glutGetModifiers;
            _exit if($m & GLUT_ACTIVE_ALT);
        },
    };
    my $key_char = chr($key);
    my $action = $dispatch_table->{$key_char};
    $action->() if($action);
    _log_state;
}
