package Iston::Object::SphereVectors;
$Iston::Object::SphereVectors::VERSION = '0.07';
use 5.16.0;

use Function::Parameters qw(:strict);
use OpenGL qw(:all);
use Iston::Utils qw/as_oga/;
use Moo::Role;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has draw_function => (is => 'lazy', clearer => 1);
has model_oga     => (is => 'rw'); # inherited from outer container


requires('vectors');
requires('vertex_indices');
requires('vertices');
requires('draw_function');
requires('vertex_to_vector_function');

with('Iston::Drawable');

method has_texture { return 0; };

method _draw_function_constructor($vertices, $indices) {
    my $vertices_oga = as_oga( $vertices );
    my ($vbo_vertices) = glGenBuffersARB_p(1);

    $vertices_oga->bind($vbo_vertices);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $vertices_oga, GL_STATIC_DRAW_ARB);


    my $indices_size = scalar(@$indices);
    my $draw_mode = GL_LINES;

    my $indices_oga =OpenGL::Array->new_list(
        GL_UNSIGNED_INT,
        @$indices
    );

    $self->shader->Enable;
    my $has_texture_u = $self->_uniform_for->{has_texture};
    my $default_color = $self->default_color;
    my $has_lighting_u = $self->_uniform_for->{has_lighting};
    my $attribute_coord3d = $self->_attribute_for->{coord3d};
    $self->shader->Disable;

    my $draw_function = sub {
        $self->shader->Enable;

        glUniform1iARB($has_lighting_u, 0);
        glUniform1iARB($has_texture_u, 0);
        $self->shader->SetMatrix(model => $self->model_oga);
        $self->shader->SetVector('default_color', @$default_color);

        glEnableVertexAttribArrayARB($attribute_coord3d);
        glBindBufferARB(GL_ARRAY_BUFFER, $vertices_oga->bound);
        glVertexAttribPointerARB_c($attribute_coord3d, 3, GL_FLOAT, 0, 0, 0);

        glDrawElements_c(GL_LINES, $indices_size, GL_UNSIGNED_INT, $indices_oga->ptr);

        glDisableVertexAttribArrayARB($attribute_coord3d);
        $self->shader->Disable;
    };
    return $draw_function;
}



1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::SphereVectors

=head1 VERSION

version 0.07

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
