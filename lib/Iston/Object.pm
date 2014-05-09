package Iston::Object;

use 5.12.0;

use Carp;
use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

has vertices => (is => 'ro', required => 1);
has colors   => (is => 'ro', required => 1);
has indices  => (is => 'ro', required => 1);

has vertices_oga => (is => 'lazy');
has colors_oga   => (is => 'lazy');

method BUILD {
    my ($v_size, $c_size) = map { scalar(@{ $self->$_ }) }
        qw/vertices colors/;
    croak "Count of vertices must match count of colors"
        unless $v_size == $c_size;
}

method _build_vertices_oga {
    return OpenGL::Array->new_list(
        GL_FLOAT,
        @{$self->vertices}
    );
};

method _build_colors_oga {
    return OpenGL::Array->new_list(
        GL_FLOAT,
        @{$self->colors}
    );
};

method draw {
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);

    my $vertices = $self->vertices_oga;
    my $triangles = ($vertices->elements / 3) - 1; # why -1 ?
    glVertexPointer_p($triangles, $vertices);
    glColorPointer_p($triangles, $self->colors_oga);

    my $indices = $self->indices;
    my $indices_size = scalar(@$indices);
    glDrawElements_s(GL_TRIANGLES, $indices_size, GL_UNSIGNED_INT,
                     pack("L${indices_size}", @$indices));
}

1;
