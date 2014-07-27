package Iston::Object::SphereVectors;
$Iston::Object::SphereVectors::VERSION = '0.04';
use 5.16.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo;
use Math::MatrixReal;
use Math::Trig;
use OpenGL qw(:all);
use Scalar::Util qw/refaddr/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'vertices'       => (is => 'ro', required => 1);
has 'vertex_indices' => (is => 'ro', required => 1);
has 'hilight_color'  => (is => 'ro', required => 1);
has 'vectors'        => (is => 'lazy');
has 'draw_function'  => (is => 'lazy', clearer => 1);

with('Iston::Drawable');

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
        $v->payload->{great_arc_normal} = $great_arc_normal;
        $v;
    } (0 .. @$indices - 2);
    return \@vectors;
};

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

    my $id = refaddr($self);
    glNewList($id, GL_COMPILE);
    $draw_function->();
    glEndList;
    $draw_function = sub {
        glCallList($id);
    };

    return $draw_function;
};

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::SphereVectors

=head1 VERSION

version 0.04

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
