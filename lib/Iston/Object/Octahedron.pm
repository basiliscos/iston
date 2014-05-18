package Iston::Object::Octahedron;

use 5.12.0;

use Carp;
use Moo;
use Function::Parameters qw(:strict);
use Iston::Vector qw/normal/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

extends 'Iston::Object';

# OK, let's calculate the defaults;
my $_PI = 4*atan2(1,0);
my $_G  = $_PI/180;
my $_R  = 0.5;

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
    0, 4, 5,
    0, 2, 5,
    1, 2, 3,
    1, 3, 4,
    1, 4, 5,
    1, 5, 2,
];

my $_normals = [
    Vector->new([0,  1,  0])->normalize,
    Vector->new([0, -1,  0])->normalize,
    Vector->new([1,  0,  1])->normalize,
    Vector->new([-1, 0,  1])->normalize,
    Vector->new([-1, 0, -1])->normalize,
    Vector->new([ 1, 0, -1])->normalize,
];

has vertices => (is => 'ro', default => sub{ $_vertices} );
has indices  => (is => 'rw', default => sub{ $_indices}  );
has normals  => (is => 'ro', default => sub{ $_normals}  );

1;
