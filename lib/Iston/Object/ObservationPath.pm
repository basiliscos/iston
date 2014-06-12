package Iston::Object::ObservationPath;
$Iston::Object::ObservationPath::VERSION = '0.02';
use 5.12.0;
use utf8;

use Function::Parameters qw(:strict);
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Moo;
use Math::MatrixReal;
use Math::Trig;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

with('Iston::Drawable');

my $_PI = 2*atan2(1,0);
my $_G2R = $_PI / 180;

has history            => (is => 'ro', required => 1);
has scale              => (is => 'rw', default => sub { 1; });
has vertices           => (is => 'rw');
has displayed_vertices => (is => 'rw');
has indices            => (is => 'rw');
has index_at           => (is => 'rw', default => sub{ {} });
has active_time        => (is => 'rw');

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

method arrow_vertices($index_to, $index_from) {
    my ($start, $end) = map { $self->vertices->[$_] } ($index_from, $index_to);
    my $direction =  $start->vector_to($end);
    my $d_normal = Vector->new([@$direction])->normalize;
    my $n = Vector->new([0, 1, 0]);
    my $scalar = reduce { $a + $b } pairwise { $a * $b} @$d_normal, @$n;
    my $f = acos($scalar);
    my $axis = ($n * $d_normal)->normalize;
    my ($x, $y, $z) = @$axis;
    my $rotation = Math::MatrixReal->new_from_rows([
        [cos($f)+(1-cos($f))*$x**2,    (1-cos($f))*$x*$y-sin($f)*$z, (1-cos($f))*$x*$z+sin($f)*$y ],
        [(1-cos($f))*$y*$z+sin($f)*$z, cos($f)+(1-cos($f))*$y**2 ,   (1-cos($f))*$y*$z-sin($f)*$x ],
        [(1-cos($f))*$z*$x-sin($f)*$y, (1-cos($f))*$z*$y+sin($f)*$x, cos($f)+(1-cos($f))*$z**2    ],
    ]);
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

method draw {
    my $scale = $self->scale;
    glScalef($scale, $scale, $scale);
    glRotatef($self->rotate(0), 1, 0, 0);
    glRotatef($self->rotate(1), 0, 1, 0);
    glRotatef($self->rotate(2), 0, 0, 1);

    my $vertices = OpenGL::Array->new_list( GL_FLOAT,
        map { @$_ } @{ $self->displayed_vertices }
    );
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer_p(3, $vertices);

    my $indices = $self->indices;
    my @passive_indices = @$indices;
    my @arrow_indices;

    glVertexPointer_p(3, $vertices);
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
    glMaterialfv_c(GL_FRONT, GL_DIFFUSE,  $diffusion->ptr);
    glMaterialfv_c(GL_FRONT, GL_AMBIENT,  $diffusion->ptr);
    glMaterialfv_c(GL_FRONT, GL_EMISSION, $emission->ptr);
    glDrawElements_p(GL_LINES, @passive_indices);

    # hilight recent active path arrow
    if (@arrow_indices) {
        my $diffusion = OpenGL::Array->new_list(GL_FLOAT, 0.0, 0.0, 0.0, 1.0);
        my $emission = OpenGL::Array->new_list(GL_FLOAT, 0.0, 0.95, 0.0, 1.0);
        glMaterialfv_c(GL_FRONT, GL_DIFFUSE, $diffusion->ptr);
        glMaterialfv_c(GL_FRONT, GL_AMBIENT, $diffusion->ptr);
        glMaterialfv_c(GL_FRONT, GL_EMISSION,$emission->ptr);
        glDrawElements_p(GL_LINES, @arrow_indices);
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::ObservationPath

=head1 VERSION

version 0.02

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
