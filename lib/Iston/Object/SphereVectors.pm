package Iston::Object::SphereVectors;

use 5.16.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix generate_list_id/;
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo::Role;
use Math::MatrixReal;
use Math::Trig;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'hilight_color'  => (is => 'ro', required => 1);
has 'draw_function'  => (is => 'lazy', clearer => 1);

requires('vectors');
requires('vertex_indices');
requires('vertices');
with('Iston::Drawable');

method arrow_vertices($index_to, $index_from) {
    my ($start, $end) = map { $self->vertices->[$_] } ($index_from, $index_to);
    my $direction =  $start->vector_to($end);
    my $d_normal = Vector->new([@$direction])->normalize;
    my $n = Vector->new([0, 1, 0]);
    my $scalar = reduce { $a + $b } pairwise { $a * $b} @$d_normal, @$n;
    my $f = acos($scalar);
    my $axis = ($n * $d_normal)->normalize;
    my $rotation = rotation_matrix(@$axis, $f);
    my $normal_distance = 0.5;
    my @normals = map { Vector->new($_) }
        ( [$normal_distance, 0, 0 ],
          [0, 0, -$normal_distance],
          [-$normal_distance, 0, 0],
          [0, 0, $normal_distance ], );
    my $length = $direction->length;
    my @results =
        map {
            for my $i (0 .. 2) {
                $_->[$i] += $start->[$i]
            }
            $_;
        }
        map { $_ * $length }
        map {
            my $r = $rotation * Math::MatrixReal->new_from_cols([ [@$_] ]);
            my $result_vector = Vector->new( [map { $r->element($_, 1) } (1 .. 3) ] );
        } @normals;
    return @results;
}

method _build_draw_function {

    # main sphere vector drawing
    my $vertex_indices = $self->vertex_indices;
    my @displayed_vertices =
        map { $self->vertices->[$_] }
        @$vertex_indices;
    my @indices = map{ ($_-1, $_) }(1 .. @displayed_vertices-1);

    # arrays for sphere vertices calculations
    for my $i (0 .. @$vertex_indices - 2 ) {
        my $v_index = $vertex_indices->[$i];
        my $last_v_index = $indices[-1];
        my @arrow_vertices = $self->arrow_vertices($v_index+1, $v_index);
        push @displayed_vertices, @arrow_vertices;
        # should be like (1, 0, 2, 0, 3, 0, 4, 0);
        my @arrow_indices =
            map { ($i+1, $_) }
            map { $last_v_index + 1 + $_ }
            (0 .. @arrow_vertices - 1);
        push @indices, @arrow_indices;
    }

    my $vertices = OpenGL::Array->new_list( GL_FLOAT,
        map { @$_ } @displayed_vertices
    );

    my $diffusion = OpenGL::Array->new_list(GL_FLOAT, 0.0, 0.0, 0.0, 1.0);
    my $emission = OpenGL::Array->new_list(GL_FLOAT, @{ $self->hilight_color });

    my $draw_function = sub {
        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer_p(3, $vertices);
        glMaterialfv_c(GL_FRONT, GL_DIFFUSE,  $diffusion->ptr);
        glMaterialfv_c(GL_FRONT, GL_AMBIENT,  $diffusion->ptr);
        glMaterialfv_c(GL_FRONT, GL_EMISSION, $emission->ptr);
        glDrawElements_p(GL_LINES, @indices);
    };

    if (@$vertex_indices > 15) {
        my ($id, $cleaner) = generate_list_id;
        glNewList($id, GL_COMPILE);
        $draw_function->();
        glEndList;
        $draw_function = sub {
            my $cleaner_ref = \$cleaner;
            glCallList($id);
        };
    }

    return $draw_function;
};

1;
