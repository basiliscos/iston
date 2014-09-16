package Iston::Object::SphereVectors::GeneralizedVectors;

use 5.16.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix generate_list_id/;
use Iston::Matrix;
use List::Util qw(max);
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Math::Trig;
use Moo;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'source_vectors'            => (is => 'ro', required => 1);
has 'distance'                  => (is => 'ro', required => 1);
has 'vectors'                   => (is => 'lazy');
has 'vertices'                  => (is => 'lazy');
has 'vertex_indices'            => (is => 'lazy');
has 'draw_function'             => (is => 'lazy');
has 'vertex_to_vector_function' => (is => 'lazy');
has '_source_to_generalized'    => (is => 'rw');


with('Iston::Object::SphereVectors');


my $_center = Vertex->new([0, 0, 0]);
my $_halfpi = pi/2;
my $_vizualization_step = deg2rad(0.5);


method _build_vectors {
    # Ramer-Douglas-Peucker algorithm applied to the sphere's great arc
    my $source_vectors = $self->source_vectors->vectors;
    my @vectors;
    my $last_index = -1;
    my $source_to_generalized = {};
    for my $i (0 .. @$source_vectors-1) {
        next if $i <= $last_index;
        $last_index = $i;
        my $start = $source_vectors->[$i];
        my $last_length = 0;
        for my $j ($i+1 .. @$source_vectors-1) {
            my ($distance, $length) = _max_distance($source_vectors, $i, $j);
            if(($distance <= $self->distance) && $length > $last_length){
                $last_index = $j;
                $last_length = $length;
            }
            else {
                last;
            };
        }
        my ($v, $idx) = do {
            if ($last_index > $i) {
                my $a = $start->payload->{start_vertex};
                my $b = $source_vectors->[$last_index]->payload->{end_vertex};
                my $v = $a->vector_to($b);
                my $great_arc_normal = $v * $_center->vector_to($a);
                $v->payload->{start_vertex    } = $a;
                $v->payload->{end_vertex      } = $b;
                $v->payload->{great_arc_normal} = $great_arc_normal;
                ($v, $last_index);
            } else {
                ($start, $i);
            }
        };
        my $length = push @vectors, $v;
        for ($i .. $idx) {
            $source_to_generalized->{$_} = $length-1;
        }
    }
    $self->_source_to_generalized($source_to_generalized);
    return \@vectors;
};

fun _max_distance($vectors, $start_idx, $end_idx) {
    my $a = $vectors->[$start_idx]->payload->{start_vertex};
    my $b = $vectors->[$end_idx]->payload->{end_vertex};
    my $great_arc_normal = $a->vector_to($b) * $_center->vector_to($a);
    my @center_vectors = (
        $_center->vector_to($a),
        map {
            my $v = $vectors->[$_];
            $_center->vector_to($v->payload->{end_vertex});
        } ($start_idx .. $end_idx)
    );
    my @distances =
        map { abs($_halfpi - $_) }
        map {
            $_->angle_with($great_arc_normal)
        } @center_vectors;
    my $distance = max(@distances);
    my ($first, $last) = @center_vectors[0, @center_vectors-1];
    my $angular_length = $first->angle_with($last);
    return ($distance, $angular_length);
}

method _build_vertex_to_vector_function {
    my $s2g = $self->_source_to_generalized;
    my $source_mapper = $self->source_vectors->vertex_to_vector_function();
    my $mapper = sub {
        my $idx = shift;
        my $source_idx = $source_mapper->($idx);
        my $g_idx = $s2g->{$source_idx};
        return $g_idx;
    };
    return $mapper;
}

method _build_vertices {
    my $vectors = $self->vectors;
    my @result = (
        $vectors->[0]->payload->{start_vertex},
        map { $_->payload->{end_vertex}} @$vectors
    );
    return \@result;
};

method _build_vertex_indices {
    my $vertices = $self->vertices;
    my @indices = (0 .. @$vertices-1);
    return \@indices;
};


method arrow_vertices($index) {
    my $end = $self->vertices->[$index];
    my $direction =  $_center->vector_to($end);
    my $d_normal = Vector->new([@$direction])->normalize;
    my $n = Vector->new([0, 1, 0]);
    my $scalar = reduce { $a + $b } pairwise { $a * $b} @$d_normal, @$n;
    my $f = acos($scalar);
    my $axis = ($n * $d_normal)->normalize;
    my $rotation = rotation_matrix(@$axis, $f);
    my $normal_distance = 0.03;
    my @normals = map { Vector->new($_) }
        ( [$normal_distance, 0, 0 ],
          [0, 0, -$normal_distance],
          [-$normal_distance, 0, 0],
          [0, 0, $normal_distance ], );
    my $length = $direction->length;
    my @results =
        map {
            for my $i (0 .. 2) {
                $_->[$i] += $end->[$i]
            }
            $_;
        }
        map { $_ * $length }
        map {
            my $r = $rotation * Iston::Matrix->new_from_cols([ [@$_] ]);
            my $result_vector = Vector->new( [map { $r->element($_, 1) } (1 .. 3) ] );
        } @normals;
    return @results;
}

method _build_draw_function {

    # main sphere vector drawing
    my $vertex_indices = $self->vertex_indices;
    my @displayed_vertices;
    my @indices;

    # @displayed_vertices =
    #     map { $self->vertices->[$_] }
    #     @$vertex_indices;
    # @indices = map{ ($_-1, $_) }(1 .. @displayed_vertices-1);

    # arrays for sphere vertices calculations
    for my $i (0 .. @$vertex_indices - 1 ) {
        my $v_index = $vertex_indices->[$i];
        my $last_v_index = $indices[-1] // -1;
        my @arrow_vertices = $self->arrow_vertices($v_index);
        push @displayed_vertices, @arrow_vertices;
        my @arrow_indices =  # cross
            map { $last_v_index + 1 + $_ }
            (0, 2, 1, 3, 0, 1, 2, 3);
        push @indices, @arrow_indices;
    }

    # build auxilary vertices to show the actual path
    my $vectors = $self->vectors;
    for my $i (0 .. @$vectors-1) {
        my $v = $vectors->[$i];
        my $start_v = $_center->vector_to($v->payload->{start_vertex});
        my $end_v   = $_center->vector_to($v->payload->{end_vertex});
        my $axis = $start_v * $v;
        my $angle = $start_v->angle_with($end_v);
        my $rotation = rotation_matrix(@$axis, $_vizualization_step);
        push @displayed_vertices, $start_v;
        for(my $phi = $_vizualization_step; $phi < $angle; $phi += $_vizualization_step) {
            my $r = $rotation * Istion::Matrix->new_from_cols([ [@$start_v] ]);
            my $result_vector = Vector->new( [map { $r->element($_, 1) } (1 .. 3) ] );
            push @displayed_vertices, $result_vector;
            push @indices, (map { ($_-2, $_-1) } scalar(@displayed_vertices) );
            $start_v = $result_vector;
        }
        push @displayed_vertices, $end_v;
        push @indices, (map { ($_-2, $_-1) } scalar(@displayed_vertices) );
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
