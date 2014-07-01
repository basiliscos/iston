package Iston::Application;

use 5.12.0;

use AntTweakBar qw/:all/;
use AnyEvent;
use Moo::Role;
use OpenGL qw(:all);
use SDL;
use SDLx::App;
use SDL::Joystick;
use SDL::Mouse;
use SDL::Video;
use SDL::Events;
use SDL::Event;

use aliased qw/Iston::Loader/;
use aliased qw/Iston::Vector/;

has camera_position => (is => 'rw', default => sub { [0, 0, -7] });
has cv_finish       => (is => 'ro', default => sub { AE::cv });
has max_boundary    => (is => 'ro', default => sub { 3.0 });
has full_screen     => (is => 'ro', default => sub { 1 });
has sdl_event       => (is => 'ro', default => sub { SDL::Event->new } );
has sdl_app         => (is => 'rw');
has width           => (is => 'rw');
has height          => (is => 'rw');
has settings_bar    => (is => 'lazy');

has history         => (is => 'rw');

requires qw/process_event/;
requires qw/objects/;

sub init_app {
    my $self = shift;

    SDL::init(SDL_INIT_VIDEO);

    my $video_info = SDL::Video::get_video_info();
    my %display_dimension = $self->full_screen
        ? (width => $video_info->current_w, height => $video_info->current_h)
        : (width => 800, height => 600);

    my %app_options = (
        title => 'Iston',
        gl    => 1,
        ($self->full_screen ? (fullscreen => 1) : ()),
        %display_dimension,
    );
    $self->sdl_app( SDLx::App->new(%app_options) );

    glutInit;
    glEnable(GL_DEPTH_TEST);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    $self->_initGL;
    AntTweakBar::init(TW_OPENGL);
    my ($width, $height) = map { $self->sdl_app->$_ } qw/w h/;
    AntTweakBar::window_size($width, $height);

    # remove all mouse motion events from queue (garbage)
    my $mouse_motion_mask = SDL_EVENTMASK(SDL_MOUSEMOTION);
    SDL::Events::peep_events($self->sdl_event, 127, SDL_GETEVENT, $mouse_motion_mask);
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
    my ($width, $height) = map { $self->sdl_app->$_ } qw/w h/;
    $self->width( $width );
    $self->height( $height );
    say "screen: ${width}x${height} px";
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    gluPerspective(65.0, $width/$height, 1, 100.0);
    glMatrixMode(GL_MODELVIEW);
    glEnable(GL_NORMALIZE);
    _init_light;
}

sub _build_settings_bar {
    AntTweakBar->new("Settings");
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
        $_->draw_function->();
        glPopAttrib;
        glPopClientAttrib;
        glPopMatrix;
    }

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_NORMALIZE);
    AntTweakBar::draw;
}

sub refresh_world {
    my $self = shift;
    $self->_handle_polls;
    $self->_drawGLScene;
    $self->sdl_app->sync;
}

sub _handle_polls {
    my $self = shift;

    SDL::Events::pump_events;
    my $event = $self->sdl_event;
    while (SDL::Events::poll_event($event)) {
        $self->process_event($event);
    }
    return $event->type != SDL_QUIT;
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
