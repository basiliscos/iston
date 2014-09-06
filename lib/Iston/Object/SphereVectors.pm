package Iston::Object::SphereVectors;
$Iston::Object::SphereVectors::VERSION = '0.05';
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::SphereVectors

=head1 VERSION

version 0.05

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
