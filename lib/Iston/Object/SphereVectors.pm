package Iston::Object::SphereVectors;

use 5.16.0;

use Function::Parameters qw(:strict);
use OpenGL qw(:all);
use Iston::Utils qw/as_oga/;
use Moo::Role;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;
use aliased qw/Iston::Matrix/;

has draw_function  => (is => 'lazy', clearer => 1);
has model_oga      => (is => 'rw'); # inherited from outer container
has spin_detection => (is => 'rw', default => sub{ 0 }, trigger => 1);

requires('vectors');
requires('vertex_indices');
requires('vertices');
requires('draw_function');
requires('vertex_to_vector_function');

with('Iston::Drawable');

method has_texture { return 0; };

method _trigger_spin_detection($value) {
    my $vectors = $self->vectors;

    if ($value) {
        my $spin_index = 0;
        my $prev_orientation;
        my $spin_start = 0;

        my $seal_spin = sub {
            my ($from, $to) = @_;
            # at least 3 vectors might form spin
            return if($to - $from < 3);
            for my $idx ($from .. $to) {
                $vectors->[$idx]->payload->{spin_index} = $spin_index;
            }
        };

        for (my $i = 0; $i < @$vectors-1; $i++) {
            my ($v1, $v2) = map { $vectors->[$_] } ($i, $i+1);
            my $n = $v1 * $v2;
            my $m = Matrix->new_from_rows([
                [@$n],
                [@$v1],
                [@$v2],
            ]);
            my $volume_orientation = $m->det;
            if (defined $prev_orientation) {
                my $same_sign = ($prev_orientation * $volume_orientation) > 0; # >=0 ?
                if (!$same_sign) {
                    $seal_spin->($spin_start, $i-1);
                    $spin_index++;
                    $spin_start = $i;
                }
            }
            $prev_orientation = $volume_orientation;
        }
        $seal_spin->($spin_start, @$vectors-1);
    }
    else {
        delete $_->payload->{spin_index} for(@$vectors);
    }
};

method detect_spins {
};

method _draw_function_constructor($vertices, $indices, $colors) {
    my $spin_detection = $self->spin_detection;
    my ($vertices_oga, $colors_oga) = map { as_oga($_) } ($vertices , $colors);
    my ($vbo_vertices, $vbo_colors) = glGenBuffersARB_p(2);

    $vertices_oga->bind($vbo_vertices);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $vertices_oga, GL_STATIC_DRAW_ARB);

    $colors_oga->bind($vbo_colors);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $colors_oga, GL_STATIC_DRAW_ARB);

    my $indices_size = scalar(@$indices);
    my $draw_mode = GL_LINES;

    my $indices_oga =OpenGL::Array->new_list(
        GL_UNSIGNED_INT,
        @$indices
    );

    $self->shader->Enable;
    my $has_texture_u = $self->_uniform_for->{has_texture};
    my $has_multicolor_u = $self->_uniform_for->{has_multicolor};
    my $default_color = $self->default_color;
    my $has_lighting_u = $self->_uniform_for->{has_lighting};
    my $attribute_coord3d = $self->_attribute_for->{coord3d};
    my $attribute_multicolor = $self->_attribute_for->{a_multicolor};
    $self->shader->Disable;

    my $draw_function = sub {
        $self->shader->Enable;

        glUniform1iARB($has_lighting_u, 0);
        glUniform1iARB($has_texture_u, 0);
        glUniform1iARB($has_multicolor_u, 1);
        $self->shader->SetMatrix(model => $self->model_oga);

        glEnableVertexAttribArrayARB($attribute_coord3d);
        glBindBufferARB(GL_ARRAY_BUFFER, $vertices_oga->bound);
        glVertexAttribPointerARB_c($attribute_coord3d, 3, GL_FLOAT, 0, 0, 0);

        glEnableVertexAttribArrayARB($attribute_multicolor);
        glBindBufferARB(GL_ARRAY_BUFFER, $colors_oga->bound);
        glVertexAttribPointerARB_c($attribute_multicolor, 4, GL_FLOAT, 0, 0, 0);

        glDrawElements_c(GL_LINES, $indices_size, GL_UNSIGNED_INT, $indices_oga->ptr);

        glDisableVertexAttribArrayARB($_) for($attribute_coord3d, $attribute_multicolor);
        $self->shader->Disable;
    };
    return $draw_function;
}



1;
