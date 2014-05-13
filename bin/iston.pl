#!/usr/bin/env perl

use 5.12.0;

use Time::HiRes qw(usleep);
use OpenGL qw(:all);

use List::Util qw/max/;
use Iston::Utils qw/vector_length/;
use Path::Tiny;
use Time::HiRes qw/gettimeofday tv_interval/;
use aliased qw/Iston::SampleTriangle/;
use aliased qw/Iston::Thetraeder/;
use aliased qw/Iston::Object/;
use aliased qw/Iston::ObjLoader/;

sub _log_state;


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
my $object = ObjLoader->new(file => $ARGV[0])->load;
my ($max_distance) =
    reverse sort {$a ->{length} <=> $b->{length} }
    map {
        { length => vector_length($_), vector => $_ }
    } $object->boudaries;

my $max_boundary = 3.8;
my $object_scale = 1/($max_distance->{length}/$max_boundary);

my $started_at = [gettimeofday];
my $history = path(".", "history_@{[ time ]}.csv")
    ->filehandle('>');
say $history "timestamp,a,b,d";
_log_state;

glutMainLoop;

sub init_light {
    # Initialize material property, light source, lighting model, 
    # and depth buffer.
    my @mat_specular = ( 0.0, 0.0, 0.01, 1.0 );
    my @mat_diffuse  = ( 0.8, 0.8, 0.8, 1.0 );
    my @light_position = ( 5.0, 5.0, 5.0, 0.0 );

    glMaterialfv_s(GL_FRONT, GL_DIFFUSE, pack("f4",@mat_diffuse));
    glMaterialfv_s(GL_FRONT, GL_SPECULAR, pack("f4",@mat_specular));
    glMaterialfv_s(GL_FRONT, GL_SHININESS, pack("f1",10));
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
    #glLoadIdentity;
    gluPerspective(65.0, $width/$height, 0.1, 100.0);
    #glFrustum(-2, 2, -2, 2, 2.5, 20.0);
    # gluPerspective(
    #     40.0,                   # field of view in degree
    #     1.0,                    # aspect ratio
    #     1.0,                    # Z near
    #     10.0,                   # Z far
    # );
    glMatrixMode(GL_MODELVIEW);
    gluLookAt(0.0, 0.0, 5.0,    # eye is at (0,0,5)
              0.0, 0.0, 0.0,    # center is at (0,0,0)
              0.0, 1.0, 0.0);   # up is in positive Y direction
    # glTranslatef(0.0, 0.0, -1.0);
    # glRotatef(60, 1.0, 0.0, 0.0);
    # glRotatef(-20, 0.0, 0.0, 1.0);
    glTranslatef(0.0, 0.0, -2.0);
}

sub drawGLScene {

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glPushMatrix;
    #glLoadIdentity;
    #glTranslatef(0.0, 0.0, -4.0);
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
    usleep (50000);
}

sub _log_state {
    my $elapsed = tv_interval ( $started_at, [gettimeofday]);
    my $line = join(',', $elapsed, $object_rotation->[1],
                    $object_rotation->[0], "0");
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
        '+' => $scaling->(1.05),
        '-' => $scaling->(0.95),
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
