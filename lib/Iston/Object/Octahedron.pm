package Iston::Object::Octahedron;

use 5.12.0;

use Carp;
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

# my $_normals = [
#     Vector->new([0,  1,  0])->normalize,
#     Vector->new([0, -1,  0])->normalize,
#     Vector->new([1,  0,  1])->normalize,
#     Vector->new([-1, 0,  1])->normalize,
#     Vector->new([-1, 0, -1])->normalize,
#     Vector->new([ 1, 0, -1])->normalize,
# ];

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

has triangles => (is => 'rw', default => sub { $_triangles} );
has vertices  => (is => 'rw', default => sub{ $_vertices} );
has indices   => (is => 'rw', default => sub{ $_indices}  );
#has normals   => (is => 'rw', default => sub{ $_normals} );
has normals   => (is => 'lazy' );

method _build_normals {
    my $triangles = $self->triangles;
    #my @t_normals = map { $_->normal } @$triangles;
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
}

method subdivide {
    my $back_to_mode = $self->mode eq 'normal' ? undef : $self->mode;
    $self->mode('normal') if defined($back_to_mode);

    my $indices = $self->indices;
    my $count = @$indices / 3;
    my @triangles =
        map { @{ $_->subdivide } }
        map {
            my @v_indices = ($_*3 .. $_*3+2);
            my @vertices =
                map { $self->vertices->[$_] }
                map { $indices->[$_] }
                @v_indices;
            Triangle->new(vertices => \@vertices);
        } (0 .. $count-1);
    my @new_vertices;
    my @new_indices;
    my $t_count = @triangles;
    for my $i (0 .. $t_count-1) {
        my $t = $triangles[$i];
        push @new_vertices, @{$t->vertices};
        my $v = $i*3;
        push @new_indices, ($v, $v+1, $v+2);
    };
    # normalizing
    my $v_count = @new_vertices;
    for my $i (0 .. $v_count-1) {
        my $original = $new_vertices[$i];
        for my $j ($i+1 .. $v_count-1) {
            my $target = $new_vertices[$j];
            next unless defined $target;
            if($target == $original) {
                $new_vertices[$j] = undef;
                for(@new_indices){
                    $_ = $i if $_ == $j;
                }
            }
        }
    }
    my $last_defined = 0;
    @new_vertices = map {
        my $i = $_;
        my $v = $new_vertices[$i];
        if (!defined($v)) {
            for (@new_indices) {
                $_-- if $_ > $last_defined;
            }
        }else {
            $last_defined++;
        }
        defined($v) ? $v : ();
    } (0 .. $v_count-1);
    $self->vertices(\@new_vertices);
    $self->indices(\@new_indices);

    $self->cache({});
    $self->mode($back_to_mode) if defined($back_to_mode);
}

1;
