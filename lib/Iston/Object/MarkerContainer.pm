package Iston::Object::MarkerContainer;

use 5.16.0;
use warnings;

use Function::Parameters qw(:strict);
use Moo;
use List::Util qw/all/;
use OpenGL qw(:all);
use Iston::Utils qw/as_oga maybe_zero/;

has draw_function  => (is => 'lazy', clearer => 1);
has zones => (is => 'ro', default => sub { [] });

with('Iston::Drawable');

method has_texture { return 0; };

method _build_draw_function {
    my $default_color = [102.0/255, 0.0, 204.0/255, 0.0];
    my $active_color = [1.0, 1.0, 1.0, 0.0];

    my $rotations = 16;
    my $step = 180 / $rotations;

    my @vertices = [0, 0, 0];
    my @indices;
    my @colors = ($default_color);
    for my $zone_idx (0 .. @{ $self->zones }-1) {
        my $zone = $self->zones->[$zone_idx];
        my @zone_vertices = map {$_->values} $zone->sphere_points(0);
        my $zone_center_idx = @vertices;
        for (my $phi = $step; $phi < 360/2; $phi += $step) {
            push @zone_vertices, map {$_->values} $zone->sphere_points($phi, 0);
        }
        push @vertices, @zone_vertices;
        # connect every vertex with center on sphere
        push @indices, map { ($zone_center_idx, $zone_center_idx + $_) } (1 .. @zone_vertices-1);
        # connect every vertex with sphere center
        push @indices, map { (0, $zone_center_idx + $_) } (1 .. @zone_vertices-1);
        # connect every non-center vertex with neiborhood
        push @indices, map {
            map { $zone_center_idx + $_ } ($_+1, $_ +3), ($_+2, $_+4);
        } (0 .. @zone_vertices-5);
        # last positive with the 1st negative
        push @indices, map { $_ + $zone_center_idx } ((@zone_vertices-2), 2);
        # last negative with the 1st positive
        push @indices, map { $_ + $zone_center_idx } ((@zone_vertices-1), 1);
        my $color = $zone->active ? $active_color : $default_color;
        push @colors, (($color) x @zone_vertices);
    }

    my ($vertices_oga, $colors_oga) = map { as_oga($_) } (\@vertices , \@colors);
    my ($vbo_vertices, $vbo_colors) = glGenBuffersARB_p(2);

    $vertices_oga->bind($vbo_vertices);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $vertices_oga, GL_STATIC_DRAW_ARB);

    $colors_oga->bind($vbo_colors);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $colors_oga, GL_STATIC_DRAW_ARB);

    my $draw_mode = GL_LINES;
    my $indices_oga =OpenGL::Array->new_list(
        GL_UNSIGNED_INT,
        @indices,
    );

    my $indices_size = @indices;

    $self->shader->Enable;
    my $has_texture_u = $self->_uniform_for->{has_texture};
    my $has_multicolor_u = $self->_uniform_for->{has_multicolor};
    my $has_lighting_u = $self->_uniform_for->{has_lighting};
    my $attribute_coord3d = $self->_attribute_for->{coord3d};
    my $attribute_multicolor = $self->_attribute_for->{a_multicolor};
    $self->shader->Disable;

    return sub {
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
};

1;
