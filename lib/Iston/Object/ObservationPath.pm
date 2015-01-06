package Iston::Object::ObservationPath;
$Iston::Object::ObservationPath::VERSION = '0.10';
use 5.16.0;
use strict;
use warnings;
use utf8;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix identity as_cartesian/;
use Iston::Matrix;
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo;
use Math::Trig;
use Math::Trig ':radial', ':pi';
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;

has history                => (is => 'ro', required => 1);
has vertices               => (is => 'rw');
has index_at               => (is => 'rw', default => sub{ {} });
has active_time            => (is => 'rw', trigger => 1);
has sphere_vertex_indices  => (is => 'rw');
has sphere_vectors         => (is => 'rw', trigger => 1);
has current_sphere_vector  => (is => 'lazy', clearer => 1);
has vertex_to_sphere_index => (is => 'rw');

has model_rotation  => (is => 'rw', default => sub { identity; }, trigger =>
    sub {
        $_[0]->clear_model_oga;
        $_[0]->clear_draw_function;
    },
);


has draw_function          => (is => 'lazy', clearer => 1);

with('Iston::Drawable');

method BUILD {
    $self->_build_vertices_and_indices;
    $self->_build_vertices_on_sphere;
}

method has_texture { return 0; }

method _build_vertices_and_indices {
    my $history = $self->history;
    my $current_point =  Iston::Matrix->new_from_cols([ [0, 0, 1] ]);
    my @vertices;
    for my $i (0 .. $history->elements-1) {
        my $record = $history->records->[$i];
        my ($dx, $dy, $timestamp) = map { $record->$_ }
            qw/x_axis_degree y_axis_degree timestamp/;
        my $v = Vertex->new(values => as_cartesian($dx, $dy));
        $v->payload->{rotation} = [$dx, $dy];
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
    #my $d_normal = Vector->new(values => [@{ $direction->values }])->normalize;
    my $n = Vector->new(values => [0, 1, 0]);
    # $f = $d_normal->angle_with($n);
    #my $scalar = reduce { $a + $b } pairwise { $a * $b} @$d_normal, @$n;
    my $scalar = $n->values->[1] * $direction->values->[1];
    my $f =  acos($scalar);
    my $axis = ($n * $direction)->normalize;
    my $rotation = rotation_matrix(@{ $axis->values}, $f);
    my $normal_distance = 0.5;
    my @normals = map { Vector->new(values => $_) }
        ( [$normal_distance, 0, 0 ],
          [0, 0, -$normal_distance],
          [-$normal_distance, 0, 0],
          [0, 0, $normal_distance ], );
    my $length = $direction->length;
    my @results =
        map { Vector->new( values => $_ ) }
        map {
            for my $i (0 .. 2) {
                $_->[$i] += $start->values->[$i]
            }
            $_;
        }
        map {
            my $r = $rotation * Iston::Matrix->new_from_cols([ $_->values ]);
            my $values = [map { $r->element($_, 1) * $length } (1 .. 3) ]
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
                default_color  => [0.0, 1.0, 0.0, 0.0],
                shader         => $self->shader,
            );
        }
    }
}

method _trigger_active_time {
    $self->clear_current_sphere_vector;
};

method _trigger_sphere_vectors($vectors) {
    $vectors->shader($self->shader);
    $self->clear_draw_function;
}

method _build_draw_function {
    my $model_oga = $self->model_oga;
    my $current = $self->current_sphere_vector;
    my $sphere_vectors = $self->sphere_vectors;

    $sphere_vectors->model_oga($model_oga);
    $current->model_oga($model_oga) if($current);

    return sub {
        $current->draw_function->() if($current);
        $sphere_vectors->draw_function->();
    };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::ObservationPath

=head1 VERSION

version 0.10

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
