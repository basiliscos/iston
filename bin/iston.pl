#!/usr/bin/env perl

use 5.12.0;

use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use List::Util qw/max/;
use OpenGL qw(:all);
use Path::Tiny;
use Text::CSV;
use Time::HiRes qw/gettimeofday tv_interval usleep sleep/;

use aliased qw/Iston::Loader/;
use aliased qw/Iston::Object::Octahedron/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

sub _log_state;
sub _replay_history;
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
#glutInitDisplayMode(GLUT_RGB | GLUT_SINGLE | GLUT_DEPTH);
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
my ($main_object, $htm);

my @other_objects;
my $max_boundary = 3.0;

my $history;
my $history_rows;
my $started_at = [gettimeofday];

if($replay_history) {
    $no_history = 1;
    _replay_history;
} else {
    $object_path = path($object_path);
    _load_object($object_path);
    if (!$no_history) {
        $history = path(".", "history_@{[ time ]}_@{[ $object_path->basename ]}.csv")
            ->filehandle('>');
        say $history "timestamp,a,b,d";
    }
    _log_state;
    glutMainLoop;
}

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

sub _read_rows {
    my $path = shift;
    my $csv = Text::CSV->new({
        binary   => 1,
        sep_char => ',',
    }) or die "Cannot use CSV: " . Text::CSV->error_diag;
    open my $fh, "<:encoding(utf8)", $path or die "$path: $!";
    my @rows;
    while ( my $row = $csv->getline( $fh ) ) {
        push @rows, $row;
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    return \@rows;
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
            _load_object($me->{path});
            my $history_idx = shift;
            my $history = $histories->[$history_idx];
            $history_rows = _read_rows($history);
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

sub _replay_history {
    _create_menu;
    my $speedup = 0.25;

    $htm = Octahedron->new;
    $htm->mode('mesh');
    my $r = Vertex->new([0, 0, 0])->vector_to($htm->vertices->[0])->length;
    my $scale_to = 1/($r/$max_boundary);
    $htm->scale($scale_to);
    $htm->level(3);
    push @other_objects, $htm;

    while(1) {
        glutPostRedisplay;
        glutMainLoopEvent;
        my $playing_history = $history_rows;
        if(!defined($playing_history)) {
            next;
        }
        my $last_time = 0;
        for my $i (1 .. @$history_rows-1) {
            glutMainLoopEvent;
            last if($playing_history != $history_rows);
            my $row = $history_rows->[$i];
            my $sleep_time = $row ->[0] - $last_time;
            my ($alpha, $beta) = @{$row}[1,2];
            for ($main_object, @other_objects) {
                $_->rotation->[1] = $alpha;
                $_->rotation->[0] = $beta;
            }
            @$camera_position = @{$row}[3 .. 5];
            glutPostRedisplay;
            sleep($sleep_time * $speedup);
            $last_time = $row->[0];
        }
        # no cycle termination by other model choosing
        sleep(3) if($playing_history == $history_rows)
    }
    for (0 .. 10) {
    }
    my $elapsed = tv_interval ( $started_at, [gettimeofday]);
    say "replay time: $elapsed";
}

sub _log_state {
    return if $no_history;
    my $elapsed = tv_interval ( $started_at, [gettimeofday]);
    my @data = (
        $elapsed,
        $main_object->rotation->[1], $main_object->rotation->[0],
        @$camera_position,
    );
    my $line = join(',', @data);
    say $history $line;
}

sub _exit {
    say "...exiting";
    _log_state;
    exit;
}

sub _load_object {
    my $path = shift;
    $main_object = Loader->new(file => $path)->load;

    my $scale_to = 1/($main_object->max_distance->length/$max_boundary);
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
