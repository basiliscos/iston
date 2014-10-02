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

has texture      => (is => 'lazy');
has texture_file => (is => 'rw', required => 0, predicate => 1);

with('Iston::Drawable');

method has_texture { return $self->has_texture_file; };

method _build_texture {
    my $texture = OpenGL::Image->new( source => $self->texture_file );
    croak("texture isn't power of 2?") if (!$texture->IsPowerOf2());
    return $texture;
}

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



1;
