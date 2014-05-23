package Iston::Object::Octahedron;

use 5.12.0;

use Carp;
use List::MoreUtils qw/first_index/;
use List::Util qw/reduce/;
use Moo;
use Function::Parameters qw(:strict);
use Iston::Vector qw/normal/;

use aliased qw/Iston::Triangle/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

extends 'Iston::Object';

# OK, let's calculate the defaults;
my $_PI = 2*atan2(1,0);
my $_G  = $_PI/180;
my $_R  = 1;

my $_vertices = [
    Vertex->new([0,  $_R, 0]), # top
    Vertex->new([0, -$_R, 0]), # bottom
    Vertex->new([$_R * sin($_G * 45) , 0, $_R * sin( $_G*45)]),  # front left
    Vertex->new([$_R * sin($_G * -45), 0, $_R * sin( $_G*45)]),  # front righ
    Vertex->new([$_R * sin($_G * -45), 0, $_R * sin(-$_G*45)]),  # back right
    Vertex->new([$_R * sin($_G * 45) , 0, $_R * sin(-$_G*45)]),  # back left
];

my $_indices = [
    0, 3, 2,
    0, 4, 3,
    0, 5, 4,
    0, 2, 5,
    1, 2, 3,
    1, 3, 4,
    1, 4, 5,
    1, 5, 2,
];

my $_triangles = [
    map {
        my @v_indices = ($_*3 .. $_*3+2);
        my @vertices =
            map { $_vertices->[$_] }
            map { $_indices->[$_] }
            @v_indices;
        Triangle->new(vertices => \@vertices, tesselation => 1);
    } (0 .. @$_indices/3 - 1)
];

has level        => (is => 'rw', default => sub { 0  }, trigger => 1 );
has levels_cache => (is => 'ro', default => sub { {} } );
has triangles    => (is => 'rw', default => sub { $_triangles} );
has normals      => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );
has vertices     => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );
has indices      => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );

method BUILD {
    $self->levels_cache->{$self->level} = $self->triangles;
}

method _build_normals {
    my $triangles = $self->triangles;
    my %triangles_of;
    for my $t (@$triangles) {
        for my $v (@{$t->vertices}) {
            push @{$triangles_of{$v}}, $t;
        }
    }
    my %normals_for = map {
        my $v = $_;
        my $avg =
            reduce { $a + $b }
            map { $_->normal }
            @{ $triangles_of{$v} };
        my $n = $avg->normalize;
        ($v => $n);
    } keys %triangles_of;
    my @normals = map { $normals_for{$_} } @{ $self->vertices };
    return \@normals;
};

method _build_vertices_and_indices {
    my %added;
    my @indices;
    my $last_idx = 0;
    my @vertices =
        map {
            my $v = $_;
            my $v_index = $added{$v};
            my $added_index;
            if (! defined($v_index) ) {
                $added{$v} = $added_index = $last_idx++;
            } else {
                $added_index = $v_index;
            }
            push @indices, $added_index;
            !defined($v_index) ? ($v) : ();
        } map { @{ $_->vertices } }
        @{ $self->triangles };
    return {
        vertices => \@vertices,
        indices  => \@indices,
    };
}

method _build_vertices {
    my $vi = $self->_build_vertices_and_indices;
    $self->indices($vi->{indices});
    return $vi->{vertices};
};

method _build_indices {
    my $vi = $self->_build_vertices_and_indices;
    $self->vertices($vi->{vertices});
    return $vi->{indices};
};

method _trigger_level($level) {
    my $back_to_mode = $self->mode eq 'normal' ? undef : $self->mode;
    #$self->mode('normal') if defined($back_to_mode);

    my $current_triangles = $self->triangles;
    for my $l (1 .. $level) {
        $self->levels_cache->{$l} //= do {
            my @triangles = map {
                @{ $_->subtriangles() }
            } @$current_triangles;
            \@triangles;
        };
        $current_triangles = $self->levels_cache->{$l};
    }
    $self->triangles($current_triangles);
    $self->clear_indices;
    $self->clear_vertices;
    $self->clear_normals;
    $self->cache({});

    $self->mode($back_to_mode) if defined($back_to_mode);
}

1;
