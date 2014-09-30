package Iston::Object::ObservationPath;
$Iston::Object::ObservationPath::VERSION = '0.07';
use 5.16.0;
use strict;
use warnings;
use utf8;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use Iston::Matrix;
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo;
use Math::Trig;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;

has history                => (is => 'ro', required => 1);
has scale                  => (is => 'rw', default => sub { 1; });
has vertices               => (is => 'rw');
has index_at               => (is => 'rw', default => sub{ {} });
has active_time            => (is => 'rw', trigger => 1);
has sphere_vertex_indices  => (is => 'rw');
has sphere_vectors         => (is => 'rw');
has current_sphere_vector  => (is => 'lazy', clearer => 1);
has vertex_to_sphere_index => (is => 'rw');

has draw_function          => (is => 'lazy', clearer => 1);

with('Iston::Drawable');

method BUILD {
    $self->_build_vertices_and_indices;
    $self->_build_vertices_on_sphere;
}

method _build_vertices_and_indices {
    my $history = $self->history;
    my $current_point =  Iston::Matrix->new_from_cols([ [0, 0, 1] ]);
    my ($x_axis_degree, $y_axis_degree) = (0, 0);
    my @vertices;
    for my $i (0 .. $history->elements-1) {
        my $record = $history->records->[$i];
        my ($dx, $dy, $timestamp) = map { $record->$_ }
            qw/x_axis_degree y_axis_degree timestamp/;
        $x_axis_degree = $dx * -1;
        $y_axis_degree = $dy * -1;
        my $x_rads = deg2rad($x_axis_degree);
        my $y_rads = deg2rad($y_axis_degree);
        my $r_a = Iston::Matrix->new_from_rows([
            [1, 0,            0            ],
            [0, cos($x_rads), -sin($x_rads)],
            [0, sin($x_rads), cos($x_rads) ],
        ]);
        my $r_b = Iston::Matrix->new_from_rows([
            [cos($y_rads),  0, sin($y_rads)],
            [0,          ,  1, 0           ],
            [-sin($y_rads), 0, cos($y_rads)],
        ]);
        my $rotation = $r_b * $r_a; # reverse order!
        my $result = $rotation * $current_point;
        my ($x, $y, $z) = map { $result->element($_, 1) } (1 .. 3);
        my $v = Vertex->new([$x, $y, $z]);
        push @vertices, $v;
        $self->index_at->{$timestamp} = $i;
    }
    $self->vertices(\@vertices);
};


method _build_vertices_on_sphere {
    my @indices;
    my %visited;
    my $vertices = $self->vertices;
    my $vertices_on_sphere = [];
    for my $idx (0 .. @$vertices - 1) {
        my $vertex = $vertices->[$idx];
        my $considered_unique = !(exists $visited{$vertex})
            || ($vertices->[$idx-1] ne $vertex);
        if($considered_unique) {
            push @indices, $idx;
            $visited{$vertex} = 1;
        }
        $vertices_on_sphere->[$idx] = @indices - 1;
    }
    $self->sphere_vertex_indices(\@indices);
    $self->vertex_to_sphere_index($vertices_on_sphere);
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

method _build_current_sphere_vector {
    my $active_time = $self->active_time;
    return unless defined $active_time;
    my $vertex_index = $self->index_at->{$active_time};
    if (defined $vertex_index && $vertex_index > 0) {
        my $v2s = $self->vertex_to_sphere_index;
        my $vertices_count = @{ $self->vertices };
        my @indices = ($vertex_index-1, $vertex_index);
        if ($indices[0] != $indices[1]) {
            return VectorizedVertices->new(
                vertices       => $self->vertices,
                vertex_indices => \@indices,
                hilight_color  => [0.0, 0.95, 0.0, 1.0],
            );
        }
    }
}

method _trigger_active_time {
    $self->clear_current_sphere_vector;
}

method _build_draw_function {
    return sub {
        my $scale = $self->scale;
        glScalef($scale, $scale, $scale);
        glRotatef($self->rotate(0), 1, 0, 0);
        glRotatef($self->rotate(1), 0, 1, 0);
        glRotatef($self->rotate(2), 0, 0, 1);
        my $current = $self->current_sphere_vector;
        $current->draw_function->() if $current;
        $self->sphere_vectors->draw_function->();
    };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::ObservationPath

=head1 VERSION

version 0.07

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
