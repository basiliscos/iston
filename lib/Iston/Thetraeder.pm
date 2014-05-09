package Iston::Thetraeder;

use 5.12.0;

use Moo;

use OpenGL qw(:all);

sub draw {
    my $verts = OpenGL::Array->new_list(
        GL_FLOAT, (
            0, 0, 1,
            0, 0.942809, -0.33333,
            -0.816497, -0.471405, -0.33333,
            0.816497,  -0.471405, -0.33333
        )
    );
    my $colors = OpenGL::Array->new_list(
        GL_FLOAT, (
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
            0, 0, 0,
        ),
    );
    # my @indices = (
    #     0,1,
    #     0,2,
    #     0,3,
    #     1, 4,
    #     1, 5,
    #     2, 6,
    #     2, 7,
    #     3, 8,
    #     3, 9,
    # );
    my @indices = (
        0,1,2,
        0,1,3,
        0,2,3,
        1,2,3,
    );
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glVertexPointer_p(3, $verts);
    glColorPointer_p(3, $colors);
    glDrawElements_s(GL_TRIANGLES, 12, GL_UNSIGNED_BYTE, pack("C12", @indices));
}

1;
