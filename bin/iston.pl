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

GetOptions(
    'o|object=s'         => \my $object_path,
    'n|no_history'       => \my $no_history,
    'r|replay_history=s' => \my $history_path,
    'h|help'             => \my $help,
);

my $show_help = $help || !$object_path;
die <<"EOF" if($show_help);
usage: $0 OPTIONS

     $0 [options]

These options are available:
  -o, --object         Generates pair of private an public keys and stores them
                       in the current directory
  -n, --no_history     Do not record history
  -r  --replay_history History file
  -h, --help           Show this message.
EOF

my $interactive_mode = !defined($history_path);

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
$object_path = path($object_path);
my $main_object = Octahedron->new;
    #Loader->new(file => $object_path)->load;
    ;
my $htm;

my @objects = ( $main_object );
my $max_boundary = 3.0;
my $scale_to = 1/($main_object->max_distance->length/$max_boundary);
$main_object->scale( $scale_to );

my $history;
my $started_at = [gettimeofday];

if($history_path) {
    $no_history = 1;
    _replay_history;
} else {
    if (!$no_history) {
        $history = path(".", "history_@{[ time ]}_@{[ $object_path->basename ]}.csv")
            ->filehandle('>');
        say $history "timestamp,a,b,d";
    }
    _log_state;
    glutMainLoop;
}

sub init_light {
    # Initialize material property, light source, lighting model, 
    # and depth buffer.
    my @mat_specular = ( 0.0, 0.0, 0.01, 1.0 );
    my @mat_diffuse  = ( 0.8, 0.8, 0.8, 1.0 );
    my @light_position = ( 5.0, 5.0, 5.0, 0.0 );

    glMaterialfv_s(GL_FRONT, GL_DIFFUSE, pack("f4",@mat_diffuse));
    glMaterialfv_s(GL_FRONT, GL_SPECULAR, pack("f4",@mat_specular));
#    glMaterialfv_s(GL_FRONT, GL_SHININESS, pack("f1",10));
    glLightfv_s(GL_LIGHT0, GL_POSITION, pack("f4",@light_position));

    glEnable(GL_LIGHT0);
    glEnable(GL_LIGHTING);
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
}

sub drawGLScene {

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glPushMatrix;
    glLoadIdentity;
    glTranslatef(@$camera_position);

    for(@objects) {
        glPushMatrix;
        $_->draw;
        glPopMatrix
    }

    glPopMatrix;
    glFlush;
    glutSwapBuffers;
    $interactive_mode && usleep(50000);
}

sub _replay_history {
    my $csv = Text::CSV->new({
        binary   => 1,
        sep_char => ',',
    }) or die "Cannot use CSV: " . Text::CSV->error_diag;
    open my $fh, "<:encoding(utf8)", $history_path or die "$history_path: $!";
    my @rows;
    while ( my $row = $csv->getline( $fh ) ) {
        push @rows, $row;
    }
    $csv->eof or $csv->error_diag();
    close $fh;

    my $speedup = 0.25;
    my $last_time = 0;

    $htm = Octahedron->new;
    $htm->mode('mesh');
    my $r = Vertex->new([0, 0, 0])->vector_to($htm->vertices->[0])->length;
    my $scale_to = 1/($r/$max_boundary);
    $htm->scale($scale_to*1.25);
    push @objects, $htm;

    for my $i (1 .. @rows-1) {
        glutMainLoopEvent;
        my $row = $rows[$i];
        my $sleep_time = $row ->[0] - $last_time;
        my ($alpha, $beta) = @{$row}[1,2];
        for (@objects) {
            $_->rotation->[1] = $alpha;
            $_->rotation->[0] = $beta;
        }
        @$camera_position = @{$row}[3 .. 5];
        glutPostRedisplay;
        sleep($sleep_time * $speedup);
        $last_time = $row->[0];
        #usleep(5000);
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

sub keyPressed {
    my ($key, $x, $y) = @_;
    my $rotate_step = 2;
    my $rotation = sub {
        my ($c, $step) = @_;
        return sub {
            $main_object->rotation->[$c] += $step;
            $main_object->rotation->[$c] %= 360;
        }
    };
    my $scaling = sub {
        my $value = shift;
        return sub {
            $main_object->scale($main_object->scale * $value);
        };
    };
    my $subdivide = sub {
        my $subject = $htm // $main_object;
        $subject->subdivide if($subject->can('subdivide'));
    };
    my $camera_z_move = sub {
        my $value = shift;
        return sub {
            $camera_position->[2] += $value;
        };
    };
    my $switch_mode = sub {
        my $subject = defined($history_path) ? $htm : $main_object;
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
        'i' => $subdivide,
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
