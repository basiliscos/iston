#!/usr/bin/env perl

use 5.12.0;

use Time::HiRes qw(usleep);
use OpenGL qw(:all);

use aliased qw/Iston::SampleTriangle/;
use aliased qw/Iston::Thetraeder/;
use aliased qw/Iston::Object/;
use aliased qw/Iston::ObjLoader/;


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
my $object_scale = 1.0;

my @objects = (
#    SampleTriangle->new,
    #Thetraeder->new,
    #ObjLoader->new(file => 'share/models/cube.obj')->load,
    ObjLoader->new(file => $ARGV[0])->load,
    # Object->new(
    #     vertices => [
    #         0, 0, 0,
    #         0, 1, 0,
    #         1, 0, 0,
    #         0.5, 2, -1,
    #     ],
    #     indices => [ 0, 1, 2, 1, 2, 3 ],
    #     normals => [
    #         0, 0, -1,
    #         0.485071, 0.485071, 0.727607,
    #         0.485071, 0.485071, 0.727607,
    #         0.657192, 0.657192, -0.369048,
    #     ],
    # ),
);

glutMainLoop;

sub init_light {
    # Initialize material property, light source, lighting model, 
    # and depth buffer.
    my @mat_specular = ( 1.0, 1.0, 0.0, 1.0 );
    my @mat_diffuse  = ( 1.0, 1.0, 1.0, 1.0 );
    my @light_position = ( 1.0, 1.0, 1.0, 0.0 );

    glMaterialfv_s(GL_FRONT, GL_DIFFUSE, pack("f4",@mat_diffuse));
    #glMaterialfv_s(GL_FRONT, GL_SPECULAR, pack("f4",@mat_specular));
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
              0.0, 1.0, 0.);    # up is in positive Y direction
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
    for(@objects) {
        glPushMatrix;
#        init_light;
        $_->draw;
        glPopMatrix
    }

    glPopMatrix;
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
    elsif ( $key == ord('+') ) {
        $object_scale *= 1.1;
    }
    elsif ( $key == ord('-') ) {
        $object_scale /= 1.1;
    }
    elsif ( $key == ord('m') ) {
        my $new_mode = $objects[0]->mode eq 'normal'
            ? 'mesh'
            : 'normal';
        $objects[0]->mode($new_mode);
    }
}
