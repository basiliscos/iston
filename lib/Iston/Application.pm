package Iston::Application;
$Iston::Application::VERSION = '0.01';
use 5.12.0;

use AnyEvent;
use Moo::Role;
use OpenGL qw(:all);

use aliased qw/Iston::Loader/;
use aliased qw/Iston::Vector/;

has camera_position => (is => 'rw', default => sub { [0, 0, -7] });
has cv_finish       => (is => 'ro', default => sub { AE::cv });
has max_boundary    => (is => 'ro', default => sub { 3.0 });
has full_screen     => (is => 'ro', default => sub { 1 });
has width           => (is => 'rw');
has height          => (is => 'rw');

has history         => (is => 'rw');

requires qw/key_pressed/;
requires qw/mouse_movement/;
requires qw/mouse_click/;
requires qw/objects/;

sub init_app {
    my $self = shift;
    glutInit;
    glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
    glEnable(GL_DEPTH_TEST);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);
    glutCreateWindow("Iston");
    my $draw_callback = sub { $self->_drawGLScene };
    glutDisplayFunc($draw_callback);
    glutIdleFunc($draw_callback);
    glutKeyboardFunc(sub { $self->key_pressed(@_) });
    glutSetCursor(GLUT_CURSOR_NONE);
    glutMouseFunc(sub { $self->mouse_click(@_) });
    glutPassiveMotionFunc(sub { $self->mouse_movement(@_) });
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glutFullScreen if $self->full_screen;
    $self->_initGL;
}

sub _init_light {
    my $self = shift;
    glShadeModel (GL_SMOOTH);

    # Initialize material property, light source, lighting model,
    # and depth buffer.
    my @mat_specular = ( 1.0, 1.0, 1.0, 1.0 );
    #my @mat_diffuse  = ( 0.1, 0.4, 0.8, 1.0 );
    my @light_position = ( 20.0, 20.0, 20.0, 0.0 );

    #glMaterialfv_s(GL_FRONT, GL_DIFFUSE, pack("f4",@mat_diffuse));
    glMaterialfv_c(GL_FRONT, GL_SPECULAR, OpenGL::Array->new_list(
        GL_FLOAT, @mat_specular)->ptr);
    glMaterialfv_c(GL_FRONT, GL_SHININESS, OpenGL::Array->new_list(
        GL_FLOAT, 120.0)->ptr);
    glLightfv_c(GL_LIGHT0, GL_POSITION, OpenGL::Array->new_list(
        GL_FLOAT, @light_position)->ptr);

    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
}

sub _initGL {
    my $self = shift;
    $self->width(glutGet( $self->full_screen ? GLUT_SCREEN_WIDTH : GLUT_WINDOW_WIDTH) );
    $self->height(glutGet( $self->full_screen ? GLUT_SCREEN_HEIGHT : GLUT_WINDOW_HEIGHT) );
    my ($width, $height) = map { $self->$_ } qw/width height/;
    say "screen: ${width}x${height} px";
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    gluPerspective(65.0, $width/$height, 1, 100.0);
    glMatrixMode(GL_MODELVIEW);
    glEnable(GL_NORMALIZE);
    glutWarpPointer($width/2, $height/2);
    _init_light;
}

sub _drawGLScene {
    my $self = shift;
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glLoadIdentity;
    glTranslatef(@{ $self->camera_position });

    for(@{ $self->objects }) {
        next if !$_ or !$_->enabled;
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
}

sub refresh_world {
    my $self = shift;
    glutMainLoopEvent;
    glutPostRedisplay;
}

sub load_object {
    my ($self, $path) = @_;
    my $object = Loader->new(file => $path)->load;

    my ($max_distance) =
        reverse sort {$a->length <=> $b->length }
        map { Vector->new( $_ ) }
        $object->boudaries;
    my $scale_to = 1/($max_distance->length/$self->max_boundary);
    $object->scale( $scale_to );
    say "model $path loaded, scaled: $scale_to";
    return $object;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Application

=head1 VERSION

version 0.01

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>,

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
