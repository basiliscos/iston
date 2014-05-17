#!/usr/bin/env perl

use 5.12.0;

use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use List::Util qw/max/;
use OpenGL qw(:all);
use Path::Tiny;
use Text::CSV;
use Time::HiRes qw/gettimeofday tv_interval usleep/;

use aliased qw/Iston::Object/;
use aliased qw/Iston::ObjLoader/;
use aliased qw/Iston::Vector/;

sub _log_state;
sub _replay_history;

GetOptions(
    'o|object=s'         => \my $object_path,
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

my $object_rotation = [0, 0, 0];
my $camera_position = [0, 0, -7];
$object_path = path($object_path);
my $object = ObjLoader->new(file => $object_path)->load;
my ($max_distance) =
    reverse sort {$a->length <=> $b->length }
    map { Vector->new( $_ ) }
    $object->boudaries;

my $max_boundary = 3.8;
my $object_scale = 1/($max_distance->length/$max_boundary);

my $history;
my $started_at = [gettimeofday];

if($history_path) {
    _replay_history;
} else {
    $history = path(".", "history_@{[ time ]}_@{[ $object_path->basename ]}.csv")
        ->filehandle('>');
    say $history "timestamp,a,b,d";
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

    glRotatef($object_rotation->[0], 1, 0, 0);
    glRotatef($object_rotation->[1], 0, 1, 0);
    glRotatef($object_rotation->[2], 0, 0, 1);
    glScalef($object_scale, $object_scale, $object_scale);

    glPushMatrix;
    $object->draw;
    glPopMatrix

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

    my $speedup = 1;
    my $last_time = 0;
    for my $i (1 .. @rows-1) {
        glutMainLoopEvent;
        my $row = $rows[$i];
        my $sleep_time = $row ->[0] - $last_time;
        $object_rotation->[1] = $row->[1];
        $object_rotation->[0] = $row->[2];
        @$camera_position = @{$row}[3 .. 5];
        #sleep($sleep_time * $speedup);
        $last_time = $row->[0];
        glutPostRedisplay;
        usleep(5000);
    }
    my $elapsed = tv_interval ( $started_at, [gettimeofday]);
    say "replay time: $elapsed";
}

sub _log_state {
    my $elapsed = tv_interval ( $started_at, [gettimeofday]);
    my @data = (
        $elapsed,
        $object_rotation->[1], $object_rotation->[0],
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
            $object_rotation->[$c] += $step;
            $object_rotation->[$c] %= 360;
        }
    };
    my $scaling = sub {
        my $value = shift;
        return sub {
            $object_scale *= $value;
        };
    };
    my $camera_z_move = sub {
        my $value = shift;
        return sub {
            $camera_position->[2] += $value;
        };
    };
    my $switch_mode = sub {
        my $new_mode = $object->mode eq 'normal'
            ? 'mesh'
            : 'normal';
        $object->mode($new_mode);
    };
    my $dispatch_table = {
        'w' => $rotation->(0, -$rotate_step),
        's' => $rotation->(0, $rotate_step),
        'a' => $rotation->(1, -$rotate_step),
        'd' => $rotation->(1, $rotate_step),
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
