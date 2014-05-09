package Iston::Object;

use 5.12.0;

use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

has vertices => (is => 'ro', required => 1);
has colors   => (is => 'ro', required => 1);
has indices  => (is => 'ro', required => 1);

method draw {
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);

    my ($vertices, $colors, $indices) =
        map { $self->$_ }
        qw/vertices colors indices/;

    my $oga_vertices = OpenGL::Array->new_list(GL_FLOAT, @$vertices);
    my $oga_colors = OpenGL::Array->new_list(GL_FLOAT, @$colors);

    my $triangles = ($oga_vertices->elements / 3) - 1; # why -1 ?
    glVertexPointer_p($triangles, $oga_vertices);
    glColorPointer_p($triangles, $oga_colors);

    my $indices_size = scalar(@$indices);
    glDrawElements_s(GL_TRIANGLES, $indices_size, GL_UNSIGNED_INT,
                     pack("L${indices_size}", @$indices));
}

1;
