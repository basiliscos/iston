package Iston::Object;

use 5.12.0;

use Carp;
use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

has vertices => (is => 'ro', required => 1);
#has colors   => (is => 'ro', required => 1);
has indices  => (is => 'ro', required => 1);
has mode     => (is => 'rw', default => sub { GL_TRIANGLES });

has vertices_oga => (is => 'lazy');
has colors_oga   => (is => 'lazy');

method BUILD {
    # my ($v_size, $c_size) = map { scalar(@{ $self->$_ }) }
    #     qw/vertices colors/;
    # croak "Count of vertices must match count of colors"
    #     unless $v_size == $c_size;
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

method _triangle_2_lines_indices {
    my $source = $self->indices;
    my ($number_of_points, $number_of_coordinates) = (3, 3);
    my $components = $number_of_points;
    my @result = map {
        my $idx = $_;
        my @v = @{$source}[$idx*3 .. $idx*3+2];
        my @r = @v[0,1,1,2,2,0];
        @r;
    } (0 .. scalar(@$source) / $components-1);
    return \@result;
}

method mesh {
    my $meshed_obj = Iston::Object->new(
        vertices => $self->vertices,
        indices  => $self->_triangle_2_lines_indices,
        mode     => GL_LINES,
    );
    return $meshed_obj;
}

method draw {
    glEnableClientState(GL_VERTEX_ARRAY);
    #glEnableClientState(GL_COLOR_ARRAY);
    glColor3f (1.0, 1.0, 1.0);

    my $vertices = $self->vertices_oga;
    my $components = 3; # number of coordinates
    glVertexPointer_p($components, $vertices);
    #glColorPointer_p($triangles, $self->colors_oga);

    my $indices = $self->indices;
    my $indices_size = scalar(@$indices);
    my $mode = $self->mode;
    glDrawElements_s($mode, $indices_size, GL_UNSIGNED_INT,
                     pack("L${indices_size}", @$indices));
}

1;
