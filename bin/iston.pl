#!/usr/bin/env perl

use 5.12.0;

use Time::HiRes qw(usleep);
use OpenGL qw(:all);
use aliased qw/Iston::SampleTriangle/;
use aliased qw/Iston::Thetraeder/;
use aliased qw/Iston::Object/;


glutInit;
glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
glEnable(GL_DEPTH_TEST);
glEnableClientState(GL_COLOR_ARRAY);
glEnableClientState(GL_VERTEX_ARRAY);
glutCreateWindow("Sample PLG Renderer");
glutDisplayFunc(\&drawGLScene);
glutIdleFunc(\&drawGLScene);
glutKeyboardFunc(\&keyPressed);
glClearColor(0.0, 0.0, 0.0, 0.0);
initGL(640, 480);

my $object_rotation = [0, 0, 0];

my @objects = (
    SampleTriangle->new,
#    Thetraeder->new,
    Object->new(
        vertices => [
            0, 0, 1,
            0, 0.942809, -0.33333,
            -0.816497, -0.471405, -0.33333,
            0.816497,  -0.471405, -0.33333
        ],
        colors   => [
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
            0, 0, 0,
        ],
        indices   => [
            0,1,2,
            0,1,3,
            0,2,3,
            1,2,3,
        ]
    ),
);

glutMainLoop;

sub initGL {
    my ($width, $height) = @_;
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    gluPerspective(65.0, $width/$height, 0.1, 100.0);
    #glFrustum(-2, 2, -2, 2, 2.5, 20.0);
    glMatrixMode(GL_MODELVIEW);
}

sub drawGLScene {

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity;
    glTranslatef(0.0, 0.0, -4.0);
    glRotatef($object_rotation->[0], 1, 0, 0);
    glRotatef($object_rotation->[1], 0, 1, 0);
    glRotatef($object_rotation->[2], 0, 0, 1);
    for(@objects) {
        glPushMatrix;
        $_->draw;
        glPopMatrix
    }

    glFlush;
    glutSwapBuffers;
    usleep (50000);
}


sub keyPressed {
    my ($key, $x, $y) = @_;
    my $rotate_step = 2;
    if ($key == ord('j') ) {
        $object_rotation->[0] += $rotate_step;
        $object_rotation->[0] %= 360;
    }
    elsif ( $key == ord('k') ) {
        $object_rotation->[1] += $rotate_step;
        $object_rotation->[1] %= 360;
    }
    elsif ( $key == ord('l') ) {
        $object_rotation->[2] += $rotate_step;
        $object_rotation->[2] %= 360;
    }
}
