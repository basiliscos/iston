package Iston::Object::HTM;
# Abstract: Hierarchical Triangular Map

use 5.12.0;

use Carp;
use Iston::Vector qw/normal/;
use List::MoreUtils qw/first_index/;
use List::Util qw/max min reduce/;
use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

use aliased qw/Iston::Triangle/;
use aliased qw/Iston::TrianglePath/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

#extends 'Iston::Object';
with('Iston::Drawable');

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
    0, 3, 2, # 0: north-front
    0, 4, 3, # 1: north-right
    0, 5, 4, # 2: north-back
    0, 2, 5, # 3: north-left
    1, 2, 3, # 4: south-front
    1, 3, 4, # 5: south-right
    1, 4, 5, # 6: south-back
    1, 5, 2, # 7: south-left
];

my $_triangles = [
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
    } (0 .. @$_indices/3 - 1)
];

has level        => (is => 'rw', default => sub { 0  }, trigger => 1 );
has levels_cache => (is => 'ro', default => sub { {} } );
has triangles    => (is => 'rw', default => sub { $_triangles} );
#has normals      => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );
#has vertices     => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );
#has indices      => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );

has scale    => (is => 'rw', default => sub { 1; });

method BUILD {
    $self->levels_cache->{$self->level} = $self->triangles;
    $self->_calculate_normals;
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
}

method rotate($axis,$value = undef){
    if (defined $value) {
        for (@{ $self->triangles }) {
            $_->rotate($axis, $value);
        }
    }
    else {
        return $self->triangles->[0]->rotate($axis);
    }
}

method radius {
    return 1;
}

method draw {
    my $scale = $self->scale;
    glScalef($scale, $scale, $scale);
    glRotatef($self->rotate(0), 1, 0, 0);
    glRotatef($self->rotate(1), 0, 1, 0);
    glRotatef($self->rotate(2), 0, 0, 1);

    for (@{ $self->triangles }) {
        next if !$_ or !$_->enabled;
        $_->draw;
    }
};

method visualize_projections ($projections) {
    my $max_level = max keys %{ $self->levels_cache };
    # disable all triangles
    for my $level (0 .. $max_level) {
        my $triangles = $self->levels_cache->{$level};
        $_->enabled(0) for (@$triangles);
    }
    $projections->walk( sub {
        my ($vertex_index, $level, $path) = @_;
        $path->apply(sub {
            my ($triangle, $path) = @_;
            $triangle->enabled(1);
        });
    });
}


1;
