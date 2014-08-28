package Iston::Object::SphereVectors;

use 5.16.0;

use Function::Parameters qw(:strict);
use Moo::Role;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'hilight_color'  => (is => 'ro', required => 1);

requires('vectors');
requires('vertex_indices');
requires('vertices');
requires('draw_function');
requires('vertex_to_vector_function');

with('Iston::Drawable');


1;
