package Iston::Object::HTM;
# Abstract: Hierarchical Triangular Map

use 5.12.0;

use Carp;
use Iston::Utils qw/generate_list_id/;
use Iston::Vector qw/normal/;
use List::MoreUtils qw/first_index/;
use List::Util qw/max min reduce/;
use Math::Trig;
use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

use aliased qw/Iston::Triangle/;
use aliased qw/Iston::TrianglePath/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

# OK, let's calculate the defaults;
my $_R  = 1;

my $_vertices = [
    Vertex->new([0,  $_R, 0]), # top
    Vertex->new([0, -$_R, 0]), # bottom
    Vertex->new([$_R * sin(deg2rad 45) , 0, $_R * sin(deg2rad  45)]),  # front left
    Vertex->new([$_R * sin(deg2rad -45), 0, $_R * sin(deg2rad  45)]),  # front righ
    Vertex->new([$_R * sin(deg2rad -45), 0, $_R * sin(deg2rad -45)]),  # back right
    Vertex->new([$_R * sin(deg2rad 45) , 0, $_R * sin(deg2rad -45)]),  # back left
];

my $_indices = [
    0, 3, 2, # 0: north-front
    0, 4, 3, # 1: north-right
    0, 5, 4, # 2: north-back
    0, 2, 5, # 3: north-left
    1, 2, 3, # 4: south-front
    1, 3, 4, # 5: south-right
    1, 4, 5, # 6: south-back
    1, 5, 2, # 7: south-left
];

has level        => (is => 'rw', default => sub { 0  }, trigger => 1 );
has levels_cache => (is => 'ro', default => sub { {} } );
has triangles    => (is => 'rw', default =>
    sub {
        my @triangles =
            map {
                my @v_indices = ($_*3 .. $_*3+2);
                my @vertices =
                    map { $_vertices->[$_] }
                    map { $_indices->[$_] }
                    @v_indices;
                Triangle->new(
                    vertices    => \@vertices,
                    path        => TrianglePath->new($_),
                    tesselation => 1,
                );
            } (0 .. @$_indices/3 - 1);
        return \@triangles;
    } );
has texture => (is => 'lazy', clearer => 1);

with('Iston::Drawable');

method BUILD {
    $self->levels_cache->{$self->level} = $self->triangles;
    $self->_calculate_normals;
    $self->_prepare_data;
};


method _calculate_normals {
    my $triangles = $self->triangles;
    my %triangles_of;
    my %index_of_vertex;
    for my $t (@$triangles) {
        my $vertices = $t->vertices;
        for my $idx (0 .. @$vertices-1) {
            my $v = $vertices->[$idx];
            push @{$triangles_of{$v}}, $t;
            $index_of_vertex{$v}->{$t} = $idx;
        }
    }
    for my $v (keys %triangles_of) {
        my $avg =
            reduce { $a + $b }
            map { $_->normal }
            @{ $triangles_of{$v} };
        my $n = $avg->normalize;
        for my $t (@{ $triangles_of{$v} }) {
            my $v_idx = $index_of_vertex{$v}->{$t};
            $t->normals->[$v_idx] = $n;
        }
    }
};

method has_texture { return 1; };

method _build_texture {
    my @triangles = grep { $_->enabled } @{ $self->triangles };
    my %share_for;
    for my $t_idx (0 .. @triangles-1) {
        my $t = $triangles[$t_idx];
        my $share = $t->{payload}->{time_share} // '';
        $share_for{$share} = 1;
    }
    my %mappings_for;
    # united texture schema:
    #
    # 02
    # 22
    # 01
    # 11
    #
    # 1 - even triangle texture share
    # 2 - odd triangle texture share
    my $square_size = 4;
    my $height  = $square_size * 2;
    my @shares = keys %share_for;
    my $squares = @shares / 2;
    $squares = 1 if $squares < 1;
    my $pow_of_2 = log($squares) / log(2);
    if ($pow_of_2 - int($pow_of_2)) {
        $pow_of_2 = int($pow_of_2) + 1;
    }
    my $width = $square_size * 2**($pow_of_2+1);
    my $texture = OpenGL::Image->new( width => $width, height => $height);
    for my $idx (0 .. @shares -1 ) {
        my $odd = $idx % 2;
        my @texture_coords = !$odd
            ? ([1, 1], [$square_size-1, 1], [$square_size-1, $square_size-1])
            : ([1, $square_size+1], [$square_size-1, $square_size+1], [$square_size-1, $square_size*2-1]);
        my $square_idx = int($idx/2);
        $_->[0] += ($square_idx * $square_size) for(@texture_coords);
        my $share = $shares[$idx];
        my @color_values = (0.0, $share, $share, 1.0);
        for(my $dy = 0; $dy < $square_size; $dy++ ){
            for(my $dx = 0; $dx < $square_size; $dx++) {
                my ($x, $y) = ($square_idx * $square_size, !$odd ? 0 : $square_size);
                $texture->SetPixel($x+$dx, $y+$dy, @color_values);
            }
        }
        my @uv_mappings_tripplet = (
            [$texture_coords[0]->[0] / $width, ($texture_coords[0]->[1]) / $height ],
            [$texture_coords[1]->[0] / $width, ($texture_coords[1]->[1]) / $height ],
            [$texture_coords[2]->[0] / $width, ($texture_coords[2]->[1]) / $height ],
        );
        $mappings_for{$share} = \@uv_mappings_tripplet;
    }
    my @uv_mappings = map {
        my $share = $_->{payload}->{time_share} // '';
        @{ $mappings_for{$share} };
    } @triangles;

    $self->uv_mappings(\@uv_mappings);
    return $texture;
};

method _prepare_data {
    my @triangles = grep { $_->enabled } @{ $self->triangles };
    my @vertices;
    my @normals;
    my @indices;
    for my $t_idx (0 .. @triangles-1) {
        my $t = $triangles[$t_idx];
        my $vertices = $t->vertices;
        my $normals = $t->normals;
        push @vertices, @$vertices;
        push @normals, @$normals;
        push @indices, map { $_ + ($t_idx*3) } (0, 1, 2);
    }
    $self->vertices(\@vertices);
    $self->normals(\@normals);
    $self->indices(\@indices);
    $self->clear_texture;
}

method _trigger_level($level) {
    my $current_triangles = $self->triangles;
    for my $l (0 .. $level) {
        $self->levels_cache->{$l} //= do {
            my @triangles = map {
                @{ $_->subtriangles() }
            } @$current_triangles;
            \@triangles;
        };
        $current_triangles = $self->levels_cache->{$l};
    }
    $self->triangles($current_triangles);
    $self->_calculate_normals;
    $self->_prepare_data;
    $self->clear_draw_function;
    $self->clear_texture;
}

method radius {
    return 1;
};

method walk_triangles($callback) {
    my $max_level = max keys %{ $self->levels_cache };
    for my $level (0 .. $max_level) {
        my $triangles = $self->levels_cache->{$level};
        $callback->($_) for (@$triangles);
    }
}

1;
