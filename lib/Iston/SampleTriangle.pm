package Iston::SampleTriangle;

use 5.12.0;

use Moo;
use OpenGL qw(:all);

sub draw {
    glDisableClientState(GL_COLOR_ARRAY);
    glColor3f (1.0, 1.0, 1.0);
    glTranslatef(0.0, 5.0, 0);
    glBegin(GL_LINE_LOOP);
    glVertex3d(-1, -1, 0);
    glVertex3d( 1, -1, 0);
    glVertex3d( 0,  0, 0);
    glEnd;
    glTranslatef(0.0, -5.0, 0);
}

1;
