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
        Triangle->new(vertices => \@vertices);
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

method _build_vertices {
    my %added;
    my @vertices =
        map {
            if (! exists $added{$_}) {
                $added{$_} = 1;
                $_;
            } else {
                ();
            }
        } map { @{ $_->vertices } }
        @{ $self->triangles };
    return \@vertices;
};

method _build_indices {
    my $vertices = $self->vertices;
    my @indices =
        map {
            my $v = $_;
            first_index { $v == $_ } @$vertices;
        } map { @{ $_->vertices } }
        @{ $self->triangles };
    return \@indices;
};

method _trigger_level($level) {
    my $back_to_mode = $self->mode eq 'normal' ? undef : $self->mode;
    #$self->mode('normal') if defined($back_to_mode);

    my $current_triangles = $self->triangles;
    $self->levels_cache->{$level} //= do {
        my @triangles = map {
            @{ $_->subtriangles() }
        } @$current_triangles;
        \@triangles;
    };
    $self->triangles($self->levels_cache->{$level});
    $self->clear_indices;
    $self->clear_vertices;
    $self->clear_normals;
    $self->cache({});

    $self->mode($back_to_mode) if defined($back_to_mode);
}

1;
