package Iston::Object::ObservationPath;

use 5.12.0;

use Function::Parameters qw(:strict);
use Moo;
use Math::MatrixReal;
use OpenGL qw(:all);

use aliased qw/Iston::Vertex/;

with('Iston::Drawable');

my $_PI = 2*atan2(1,0);
my $_G2R = $_PI / 180;

has history  => (is => 'ro', required => 1);
has scale    => (is => 'rw', default => sub { 1; });
has rotation => (is => 'rw', default => sub { [0, 0, 0] });
has vertices => (is => 'rw');
has indices  => (is => 'rw');

method BUILD {
    $self->_build_vertices_and_indices;
}

method _build_vertices_and_indices {
    my $history = $self->history;
    my $current_point =  Math::MatrixReal->new_from_rows([ [0], [0], [1] ]);
    my ($x_axis_degree, $y_axis_degree) = (0, 0);
    my @vertices;
    my @indices;
    for my $i (0 .. $history->elements-1) {
        my $record = $history->records->[$i];
        my ($dx, $dy) = map { $record->$_ } qw/x_axis_degree y_axis_degree/;
        $x_axis_degree = $dx * -1;
        $y_axis_degree = $dy * -1;
        my $r_a = Math::MatrixReal->new_from_rows([
            [1, 0,                                 0                 ],
            [0, cos($x_axis_degree*$_G2R), -sin($x_axis_degree*$_G2R)],
            [0, sin($x_axis_degree*$_G2R), cos($x_axis_degree*$_G2R) ],
        ]);
        my $r_b = Math::MatrixReal->new_from_rows([
            [cos($y_axis_degree*$_G2R),  0, sin($y_axis_degree*$_G2R)],
            [0,                       ,  1, 0                        ],
            [-sin($y_axis_degree*$_G2R), 0, cos($y_axis_degree*$_G2R)],
        ]);
        my $rotation = $r_b * $r_a; # reverse order!
        my $result = $rotation * $current_point;
        my ($x, $y, $z) = map { $result->element($_, 1) } (1 .. 3);
        my $v = Vertex->new([$x, $y, $z]);
        push @vertices, $v;
        push @indices, $i-1, $i if($i);
    }
    $self->vertices(\@vertices);
    $self->indices(\@indices);
}

method draw {
    my $scale = $self->scale;
    glScalef($scale, $scale, $scale);
    glRotatef($self->rotation->[0], 1, 0, 0);
    glRotatef($self->rotation->[1], 0, 1, 0);
    glRotatef($self->rotation->[2], 0, 0, 1);

    my $vertices = OpenGL::Array->new_list( GL_FLOAT,
        map { @$_ } @{ $self->vertices }
    );
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer_p(3, $vertices);

    # applying material properties to the whole object
    glMaterialfv_s(GL_FRONT, GL_DIFFUSE,   pack("f4", 0.45, 0.0, 0,0, 1.0 ));
    glMaterialfv_s(GL_FRONT, GL_AMBIENT,   pack("f4", 0.45, 0.0, 0,0, 1.0 ));
    glMaterialfv_s(GL_FRONT, GL_EMISSION,  pack("f4", 0.45, 0.0, 0,0, 1.0 ));

    my $indices = $self->indices;
    glDrawElements_p(GL_LINES, @$indices);
}

1;
