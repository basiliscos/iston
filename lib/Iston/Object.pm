package Iston::Object;

use 5.16.0;

use Carp;
use Iston::Matrix;
use Iston::Utils qw/generate_list_id identity/;
use Moo;
use List::Util qw/max/;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);
use OpenGL::Image;

use aliased qw/Iston::Vertex/;

with('Iston::Drawable');

has texture_file => (is => 'rw', required => 0);

method _build_center {
    my ($v_size, $n_size) = map { scalar(@{ $self->$_ }) }
        qw/vertices normals/;
    croak "Count of vertices must match count of normals"
        unless $v_size == $n_size;

    my($mins, $maxs) = map { $self->boundaries->[$_] } (0, 1);
    my @avgs = map { ($mins->[$_] + $maxs->[$_]) /2  } (0 .. 2);
    return Vertex->new(\@avgs);
};

method radius {
    my $c = $self->center;
    my $r = max(
        map { $_->length }
        map { $c->vector_to($_) }
        @{ $self->vertices }
    );
    $r;
}

method _build_texture_id {
    return if(!defined($self->uv_mappings) or !defined($self->texture_file));

    my ($texture_id) = glGenTextures_p(1);
    my $texture = OpenGL::Image->new( source => $self->texture_file);

    my($internal_format, $format, $type) = $texture->Get('gl_internalformat','gl_format','gl_type');
    my($texture_width, $texture_height) = $texture->Get('width','height');

    die ("texture isn't power of 2?") if (!$texture->IsPowerOf2());

    glBindTexture(GL_TEXTURE_2D, $texture_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D_c(GL_TEXTURE_2D, 0, $internal_format, $texture_width, $texture_height,
                   0, $format, $type, $texture->Ptr());

    return $texture_id;
}


1;
