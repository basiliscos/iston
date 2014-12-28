package Iston::Triangle;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::Vector;
use Iston::Utils qw/maybe_zero/;
use List::MoreUtils qw/pairwise all/;
use List::Util qw/first reduce/;
use Moo;

use aliased qw/Iston::Matrix/;
use aliased qw/Iston::Triangle/;
use aliased qw/Iston::TrianglePath/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

with('Iston::Payload');

has vertices => (is => 'rw', required => 1, isa =>
    sub {
        die "Triangle should have exactly 3 vertices"
            unless @{$_[0]} == 3;
    }
);
has path         => (is => 'ro', required => 1);

has indices      => (is => 'rw', default => sub { [0, 1, 2 ] });
has normals      => (is => 'rw', default => sub { [] });   # vertices normals
has normal       => (is => 'lazy'); # triangle normal
has subtriangles => (is => 'lazy');
has tesselation  => (is => 'ro', default => sub { 0  });
has enabled      => (is => 'rw', default => sub { 1 });

method BUILD {
    $self->path->triangle($self);
}

method _build_normal {
    return Iston::Vector::normal($self->vertices, [0 .. 2]);
};

method _build_subtriangles {
    my @vertex_pairs = (
        [ [0, 1], [0, 2] ],
        [ [1, 0], [1, 2] ],
        [ [2, 0], [2, 1] ],
    );
    my $do_tesselation = $self->tesselation;
    my $vertices = $self->vertices;
    my $example_radius = $do_tesselation
        ? sqrt(reduce {$a + $b} map { $_**2 } @{$vertices->[0]})
        : 0;
    my @mediate_vectors = map {
        my ($A, $B) = map {
            my ($v1, $v2) = map { $vertices->[$_] } @$_;
            my @vector = pairwise { $b - $a } @$v1, @$v2;
            #$v1->vector_to($v2);
            \@vector;
        } @$_;
        my @values = pairwise { ($a + $b)/2 } @$A, @$B;
        \@values;
        #Iston::Vector->new(\@values);
    } @vertex_pairs;
    my @new_vertices = map {
        my $vector = $mediate_vectors[$_];
        my $base_vertex = $vertices->[ $vertex_pairs[$_]->[0]->[0] ];
        # move vector to at the base vertex
        my @values = pairwise { $a + $b } @$vector, @$base_vertex;
        if ($do_tesselation) {
            my $radius = sqrt(reduce {$a + $b} map { $_**2 } @values);
            my $scale = $example_radius / $radius;
            $_ *= $scale for (@values);
        }
        Iston::Vertex->new(\@values);
    } (0 .. 2);
    my @new_triangle_vertices = (
        # reserve vertices traverse order
        [$vertices->[0],   $new_vertices[2], $new_vertices[1]],
        [$vertices->[1],   $new_vertices[0], $new_vertices[2]],
        [$vertices->[2],   $new_vertices[1], $new_vertices[0]],
        [$new_vertices[2], $new_vertices[0], $new_vertices[1]],
    );
    my $base_path = $self->path;
    my @new_triangles = map {
        my $vertices = $new_triangle_vertices[$_];
        Triangle->new(
            vertices    => $vertices,
            path        => TrianglePath->new($base_path, $_),
            tesselation => $do_tesselation,
        )
    } (0 .. @new_triangle_vertices-1);
    return \@new_triangles;
};

=method intersects_with

Finds the vertex, which is get via intersection a line from
(0,0,0) (center of sphere with radus = 1) and the vertex on the
sphere with the plane, formed by current tirangle.

If no intersection can be found or it is outside the triangle
undef is returned

=cut

method intersects_with($vertex_on_sphere) {
    my $n = $self->normal;
    my $a = Vector->new([@$vertex_on_sphere]); # guide vector
    my $an = $a->scalar_multiplication($n);
    return if maybe_zero(abs($an)) == 0;
    my $r0 = Vector->new($self->vertices->[0]);
    my $t = $r0->scalar_multiplication($n) / $an;
    my $vertex_on_triangle = Vertex->new($a*$t);

    # # now, check, wheather the vertex is inside the triangle
    my @indices = (
        [0, 1],
        [1, 2],
        [2, 0],
    );

    # this works, while this is more elegant, but it is more slower too :(
    # my $to_a = Vector->new($a);
    # my @orientations = map {
    #     my ($a, $b) = map {$self->vertices->[$_]} @$_;
    #     my $orientation = Matrix->new_from_rows([
    #         [@$a],
    #         [@$b],
    #         [@$to_a],
    #     ])->det
    # } @indices;
    # my @values = map { maybe_zero($_) } @orientations;
    # # planes, formed by the tringle sidies
    my @planes = map {
        my ($a, $b) = map {$self->vertices->[$_]} @$_;
        my $normal = $a->vector_to($b)*$n;
        my $alpha = Vector->new($a)->scalar_multiplication($normal);
        [$normal, $alpha];
    } @indices;
    my $vector_to_triangle = Vector->new($vertex_on_triangle);
    my @values =
        map { maybe_zero($_) }
        map {
            my ($normal, $alpha) = @$_;
            $vector_to_triangle->scalar_multiplication($normal) - $alpha;
        } @planes;

    # redundant checks
    # my @signes = map { $_ > 0 ? 1 : $_ < 0 ? -1 : 0 } @values;
    # my $any_non_zero = first { $_  } @signes;
    # my $is_inside = all { $_ == 0 or $_ == $any_non_zero } @signes;
    my $is_inside = all { $_ <= 0 } @values;

    return $is_inside ? $vertex_on_triangle : undef;
}

1;
