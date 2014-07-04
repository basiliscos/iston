package Iston::Object::ObservationPath;

use 5.12.0;
use utf8;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo;
use Math::MatrixReal;
use Math::Trig;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

my $_PI = 2*atan2(1,0);
my $_G2R = $_PI / 180;

has history               => (is => 'ro', required => 1);
has scale                 => (is => 'rw', default => sub { 1; });
has vertices              => (is => 'rw');
has displayed_vertices    => (is => 'rw');
has indices               => (is => 'rw');
has index_at              => (is => 'rw', default => sub{ {} });
has active_time           => (is => 'rw', trigger => 1);
has unique_vertex_indices => (is => 'lazy');

has draw_function          => (is => 'lazy', clearer => 1);

with('Iston::Drawable');

method BUILD {
    $self->_build_vertices_and_indices;
}

method _build_vertices_and_indices {
    my $history = $self->history;
    my $current_point =  Math::MatrixReal->new_from_cols([ [0, 0, 1] ]);
    my ($x_axis_degree, $y_axis_degree) = (0, 0);
    my @vertices;
    my @indices;
    for my $i (0 .. $history->elements-1) {
        my $record = $history->records->[$i];
        my ($dx, $dy, $timestamp) = map { $record->$_ }
            qw/x_axis_degree y_axis_degree timestamp/;
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
        $self->index_at->{$timestamp} = $i;
    }
    $self->vertices(\@vertices);
    $self->indices(\@indices);

    my @displayed_vertices = @vertices;
    # constuct arraw vertices & indices
    for my $v_index (0 .. @vertices - 2 ) {
        my $last_v_index = @displayed_vertices - 1;
        my @arrow_vertices = $self->arrow_vertices($v_index+1, $v_index);
        push @displayed_vertices, @arrow_vertices;
        # should be like (1, 0, 2, 0, 3, 0, 4, 0);
        my @arrow_indices =
            map { ($v_index + 1, $_) }
            map { $last_v_index + 1 + $_}
            (0 .. @arrow_vertices - 1);
        push @indices, @arrow_indices;
    }
    $self->displayed_vertices(\@displayed_vertices);
};

method _build_unique_vertex_indices {
    my @indices;
    my %visited;
    my $vertices = $self->vertices;
    for my $idx (0 .. @$vertices - 1) {
        my $vertex = $vertices->[$idx];
        if(! exists $visited{$vertex}) {
            push @indices, $idx;
            $visited{$vertex} = 1;
        }
    }
    return \@indices;
}

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
        ([$normal_distance, 0, 0], [0, 0, -$normal_distance], [-$normal_distance, 0, 0], [0, 0, $normal_distance]);
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

method _trigger_active_time {
    $self->clear_draw_function;
}

method _build_draw_function {

    my $vertices = OpenGL::Array->new_list( GL_FLOAT,
        map { @$_ } @{ $self->displayed_vertices }
    );

    my $indices = $self->indices;
    my @passive_indices = @$indices;
    my @arrow_indices;

    # calculate recent active path
    my $active_time = $self->active_time;
    if (defined $active_time && exists $self->index_at->{$active_time}) {
        my $vertices_count = @{ $self->vertices };
        my $vertex_index = $self->index_at->{$active_time};
        if ($vertex_index < $vertices_count - 1 ) {
            my $count = 4; # 4 arrow lines
            @arrow_indices = splice(
                @passive_indices,
                ($vertices_count-1)*2 + ($vertex_index * 2 * $count),
                2 * $count,
            );
        }
    }

    my $diffusion = OpenGL::Array->new_list(GL_FLOAT, 0.0, 0.0, 0.0, 1.0);
    my $emission = OpenGL::Array->new_list(GL_FLOAT, 0.75, 0.0, 0.0, 1.0);
    my $hilight_emission = OpenGL::Array->new_list(GL_FLOAT, 0.0, 0.95, 0.0, 1.0);

    return sub {
        my $scale = $self->scale;
        glScalef($scale, $scale, $scale);
        glRotatef($self->rotate(0), 1, 0, 0);
        glRotatef($self->rotate(1), 0, 1, 0);
        glRotatef($self->rotate(2), 0, 0, 1);

        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer_p(3, $vertices);

        glMaterialfv_c(GL_FRONT, GL_DIFFUSE,  $diffusion->ptr);
        glMaterialfv_c(GL_FRONT, GL_AMBIENT,  $diffusion->ptr);
        glMaterialfv_c(GL_FRONT, GL_EMISSION, $emission->ptr);
        glDrawElements_p(GL_LINES, @passive_indices);

        # hilight recent active path arrow
        if (@arrow_indices) {
            glMaterialfv_c(GL_FRONT, GL_DIFFUSE,  $diffusion->ptr);
            glMaterialfv_c(GL_FRONT, GL_AMBIENT,  $diffusion->ptr);
            glMaterialfv_c(GL_FRONT, GL_EMISSION, $hilight_emission->ptr);
            glDrawElements_p(GL_LINES, @arrow_indices);
        }
    };

}

1;
