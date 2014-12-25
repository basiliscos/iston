package Iston::Object::SphereVectors::VectorizedVertices;

use 5.16.0;

use Function::Parameters qw(:strict);
use Iston::Matrix;
use Iston::Utils qw/rotation_matrix generate_list_id/;
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo;
use Math::Trig;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'vertices'                  => (is => 'ro', required => 1);
has 'vectors'                   => (is => 'lazy');
has 'vertex_indices'            => (is => 'ro', required => 1);
has 'vertex_to_vector_function' => (is => 'lazy');

with('Iston::Object::SphereVectors');

method _build_vectors {
    my $vertices = $self->vertices;
    my $indices = $self->vertex_indices;
    my $center = Vertex->new([0, 0, 0]);
    my @vectors = map {
        my @uniq_indices = @{$indices}[$_, $_+1];
        my ($a, $b) = map { $vertices->[$_] } @uniq_indices;
        my $v = $a->vector_to($b);
        my $great_arc_normal = $v * $center->vector_to($a);
        $v->payload->{start_vertex    } = $a;
        $v->payload->{end_vertex      } = $b;
        $v->payload->{start_vertex_idx} = $uniq_indices[0];
        $v->payload->{end_vertex_idx  } = $uniq_indices[-1];
        $v->payload->{great_arc_normal} = $great_arc_normal;
        $v;
    } (0 .. @$indices - 2);
    return \@vectors;
};

method _build_vertex_to_vector_function {
    my $vectors = $self->vectors;
    my @values = map {
            my $vector_idx = $_;
            my $payload = $vectors->[$vector_idx]->payload;
            my @values = map {
                ($_ => $vector_idx)
            } ($payload->{start_vertex_idx} .. $payload->{end_vertex_idx});
            @values;
        } (0 .. @$vectors-1);
    my $index_of = {};
    for my $idx (0 .. @values/2-1) {
        my ($k, $v) = map { $values[$_] } ($idx*2, $idx*2+1);
        $index_of->{$k} //= $v;
    }
    my $last_vector_idx = @$vectors - 1;
    my $mapper = sub {
        my $idx = shift;
        my $value = $idx >= 0 ? $index_of->{$idx} // $last_vector_idx : undef;
        return $value;
    };
    return $mapper;
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
            my $r = $rotation * Iston::Matrix->new_from_cols([ [@$_] ]);
            my $result_vector = Vector->new( [map { $r->element($_, 1) } (1 .. 3) ] );
        } @normals;
    return @results;
}

method _build_draw_function {
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

    my $default_color = $self->default_color;
    my @colors = map { $default_color } (0 .. @indices-1);

    return $self->_draw_function_constructor(\@displayed_vertices, \@indices, \@colors);
}

1;
