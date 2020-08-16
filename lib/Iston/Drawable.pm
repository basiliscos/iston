package Iston::Drawable;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::Utils qw/identity as_oga/;
use Moo::Role;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

# candidate for deletion
has rotation     => (is => 'rw', default => sub { [0, 0, 0] }, trigger => 1);
has enabled      => (is => 'rw', default => sub { 1 });
# candidate for deletion
has display_list => (is => 'ro', default => sub { 0 });

has center        => (is => 'lazy');
has boundaries    => (is => 'lazy');
has scale         => (is => 'rw', default => sub { 1; }, trigger => 1);
has vertices      => (is => 'rw', required => 0);
has indices       => (is => 'rw', required => 0);
has normals       => (is => 'rw', required => 0);
has texture       => (is => 'rw', clearer => 1);
has multicolor    => (is => 'rw', clearer => 1, predicate => 1);
has uv_mappings   => (is => 'rw', required => 0, clearer => 1);
has mode          => (is => 'rw', default => sub { 'normal' }, trigger => 1);
has default_color => (is => 'rw', default => sub { [1.0, 1.0, 1.0, 0.0] } );
has lighting      => (is => 'rw', default => sub { 1; });

has texture_id    => (is => 'lazy', clearer => 1);
has draw_function => (is => 'lazy', clearer => 1);

has shader                 => (is => 'rw', trigger => 1 );
has notifyer               => (is => 'rw', trigger => 1 );
has _uniform_for   => (is => 'ro', default => sub { {} } );
has _attribute_for => (is => 'ro', default => sub { {} } );

has _text_coords_oga => (is => 'lazy', clearer => 1);

# matrices
has model           => (is => 'rw', trigger => sub{ $_[0]->reset_model }, default => sub { identity; });
has model_translate => (is => 'rw', trigger => sub{ $_[0]->reset_model }, default => sub { identity; });
has model_scale     => (is => 'rw', trigger => sub{ $_[0]->reset_model }, default => sub { identity; });
has model_rotation  => (is => 'rw', trigger => sub{ $_[0]->reset_model }, default => sub { identity; });

has model_oga       => (is => 'lazy', clearer => 1);
has model_view_oga  => (is => 'lazy', clearer => 1);  # transpose (inverse( view * model))

# just cache
has _contexts => (is => 'rw', default => sub { {} });

requires 'has_texture';

method reset_model() {
    $self->clear_model_oga;
    $self->clear_model_view_oga;
}

method _trigger_shader($shader) {
    return unless $shader;
    for (qw/mytexture has_texture has_multicolor has_lighting default_color view_model/) {
        my $id = $shader->Map($_);
        croak "cannot map '$_' uniform" unless defined $id;
        $self->_uniform_for->{$_} = $id;
    }
    for (qw/texcoord coord3d N a_multicolor/) {
        my $id = $shader->MapAttr($_);
        croak "cannot map attribute '$_'" unless defined $id;
        $self->_attribute_for->{$_} = $id;
    }
}

method _trigger_notifyer($notifyer) {
    $notifyer->subscribe(view_change => sub { $self->clear_model_view_oga } );
}

method _trigger_rotation($values) {
    my $m = identity;
    for my $idx (0 .. @$values-1) {
        my $angle = $values->[$idx];
        if($angle) {
            my @axis_components = (0) x scalar(@$values);
            $axis_components[$idx] = 1;
            my $axis = Vector->new(values => \@axis_components);
            $m *= Iston::Utils::rotate($angle, $axis->values);
        }
    }
    $self->model_rotation($m);
}

method _trigger_scale($value) {
    $self->model_scale(Iston::Utils::scale($value));
}

sub _build_model_oga {
    my $self = shift;
    my $scale    = $self->model_scale;
    my $translate = $self->model_translate;
    my $rotation = $self->model_rotation;
    my $model = $self->model;
    my $matrix = $model * $rotation * $scale * $translate;
    $matrix = ~$matrix;
    return OpenGL::Array->new_list(GL_FLOAT, $matrix->as_list);
}

method _build_model_view_oga() {
    my $scale    = $self->model_scale;
    my $translate = $self->model_translate;
    my $rotation = $self->model_rotation;
    my $model = $self->model * $rotation * $scale * $translate;
    my $view = $self->notifyer->last_value('view_change');
    my $matrix = (~($model * $view))->inverse;
    $matrix = ~$matrix;
    return OpenGL::Array->new_list(GL_FLOAT, $matrix->as_list);
}

# candidate for deletion
sub rotate {
    my ($self, $axis, $value) = @_;
    if (defined $value) {
        $self->rotation->[$axis] = $value;
        $self->_trigger_rotation($self->rotation);
    }
    else {
        return $self->rotation->[$axis];
    }
}

method reset_texture() {
    $self->clear_texture;
    $self->clear_texture_id;
    $self->_clear_text_coords_oga;
    $self->clear_draw_function;
    $self->clear_uv_mappings;
}

method _trigger_mode(@) {
    my $mode = $self->mode;
    if ($mode eq 'mesh') {
        $self->_contexts->{normal} = {
            indices => $self->indices,
        };
        $self->indices($self->_triangle_2_lines_indices);
    } else {
        $self->_contexts->{mesh} = {
            indices => $self->indices,
        };
        $self->indices($self->_contexts->{normal}->{indices});
    }
    $self->clear_draw_function;
};

method _triangle_2_lines_indices() {
    my $source = $self->indices;
    my $components = 3;
    my @result = map {
        my $idx = $_;
        my @v = @{$source}[$idx*3 .. $idx*3+2];
        my @r = @v[0,1,1,2,2,0];
        @r;
    } (0 .. scalar(@$source) / $components-1);
    return \@result;
};

method _build_boundaries() {
    my $first_vertex = $self->vertices->[0];
    my ($mins, $maxs) = map { [@{ $first_vertex->values }] } (0 .. 1);
    my $vertices_count = scalar(@{$self->vertices});
    for my $vertex_index (0 .. $vertices_count-1) {
        my $v = $self->vertices->[$vertex_index]->values;
        for my $c (0 .. 2) {
            $mins->[$c] = $v->[$c] if($mins->[$c] > $v->[$c]);
            $maxs->[$c] = $v->[$c] if($maxs->[$c] < $v->[$c]);
        }
    }
    return [map {Vertex->new(values => $_)} $mins, $maxs];
};

method _build__text_coords_oga() {
    my ($vbo_texcoords) = glGenBuffersARB_p(1);
    my $texcoords_oga = OpenGL::Array->new_list(
        GL_FLOAT, map { @$_ } @{ $self->uv_mappings }
    );
    $texcoords_oga->bind($vbo_texcoords);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $texcoords_oga, GL_STATIC_DRAW_ARB);
    return $texcoords_oga;
}

method _build_texture_id() {
    croak("Generating texture for textureless object")
        unless $self->has_texture;

    my ($texture_id) = glGenTextures_p(1);

    my $texture = $self->texture;
    my $format = $texture->format;
    my $bpp = $format->BytesPerPixel;
    my $rmask = $format->Rmask;
    my $texture_format = $bpp == 4
        ? ($rmask == 0x000000ff ? GL_RGBA : GL_BGRA)
        : ($rmask == 0x000000ff ? GL_RGB  : GL_BGR );

    my($texture_width, $texture_height) = map { $texture->$_ } qw/w h/;

    say sprintf('texture bpp: %d, rmask: %x, gmask: %x, bmask: %x, amask: %x',
                $format->BytesPerPixel,
                $format->Rmask, $format->Gmask, $format->Bmask, $format->Amask
        );

    glBindTexture(GL_TEXTURE_2D, $texture_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D_s(GL_TEXTURE_2D, 0, $texture_format, $texture_width, $texture_height,
                   0, $texture_format, GL_UNSIGNED_BYTE, ${ $texture->get_pixels_ptr });

    $self->clear_texture; # we do not need texture any more
    return $texture_id;
}

method _build_draw_function() {
    my ($p_vertices, $p_normals) =
        map {
            my $v = $self->$_;
            croak "$_ is mandatory" if (!defined($v) or !@$v);
            $v;
        } qw/vertices normals/;
    my ($vertices, $normals) =
        map { as_oga($_) }
        ($p_vertices, $p_normals);
    my ($vbo_vertices, $vbo_normals, $vbo_colors) = glGenBuffersARB_p(3);

    my $has_multicolor = $self->has_multicolor;
    my $multicolors;

    $vertices->bind($vbo_vertices);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $vertices, GL_STATIC_DRAW_ARB);

    $normals->bind($vbo_normals);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $normals, GL_STATIC_DRAW_ARB);

    if ($has_multicolor) {
        $multicolors = as_oga($self->multicolors);
        $multicolors->bind($vbo_colors);
        glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $multicolors, GL_STATIC_DRAW_ARB);
    }

    my $indices = $self->indices;
    my $indices_size = scalar(@$indices);
    my $mode = $self->mode;
    my $draw_mode = $mode eq 'normal'
        ? GL_TRIANGLES : GL_LINES;

    my $indices_oga =OpenGL::Array->new_list(
        GL_UNSIGNED_INT,
        @$indices
    );

    $self->shader->Enable;
    my $has_texture_u     = $self->_uniform_for->{has_texture };
    my $has_lighting_u   = $self->_uniform_for->{has_lighting};
    my $has_multicolor_u = $self->_uniform_for->{has_multicolor};
    my $my_texture_u     = $self->_uniform_for->{mytexture};
    my $view_model_u     = $self->_uniform_for->{view_model};

    my ($texture_id, $default_color);
    if ($self->has_texture) {
        $texture_id = $self->texture_id;
    } else {
        $default_color = $self->default_color;
    }

    my $attribute_texcoord   = $self->_attribute_for->{texcoord    };
    my $attribute_coord3d    = $self->_attribute_for->{coord3d     };
    my $attribute_normal     = $self->_attribute_for->{N           };
    my $attribute_multicolor = $self->_attribute_for->{a_multicolor};

    $self->shader->Disable;

    my $draw_function = sub {
        $self->shader->Enable;

        my @enabled_attributes;
        glUniform1iARB($has_lighting_u, $self->lighting);
        glUniform1iARB($has_texture_u, $self->has_texture);
        glUniform1iARB($has_multicolor_u, $self->has_multicolor);

        $self->shader->SetMatrix(model => $self->model_oga);
        $self->shader->SetMatrix(view_model => $self->model_view_oga);

        if (defined $texture_id) {
            glActiveTextureARB(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, $texture_id);
            glUniform1iARB($my_texture_u, 0); # /*GL_TEXTURE*/

            glEnableVertexAttribArrayARB($attribute_texcoord);
            glBindBufferARB(GL_ARRAY_BUFFER, $self->_text_coords_oga->bound);
            glVertexAttribPointerARB_c($attribute_texcoord, 2, GL_FLOAT, 0, 0, 0);
            push @enabled_attributes, $attribute_texcoord;
        } else {
            if ($self->has_multicolor) {
                glEnableVertexAttribArrayARB($attribute_multicolor);
                glBindBufferARB(GL_ARRAY_BUFFER, $multicolors->bound);
                glVertexAttribPointerARB_c($attribute_multicolor, 4, GL_FLOAT, 0, 0, 0);
                push @enabled_attributes, $attribute_multicolor;
            } else {
                $self->shader->SetVector('default_color', @$default_color);
            }
        }

        glEnableVertexAttribArrayARB($attribute_coord3d);
        glBindBufferARB(GL_ARRAY_BUFFER, $vertices->bound);
        glVertexAttribPointerARB_c($attribute_coord3d, 3, GL_FLOAT, 0, 0, 0);
        push @enabled_attributes, $attribute_coord3d;

        glEnableVertexAttribArrayARB($attribute_normal);
        glBindBufferARB(GL_ARRAY_BUFFER, $normals->bound);
        glVertexAttribPointerARB_c($attribute_normal, 3, GL_FLOAT, 0, 0, 0);

        glDrawElements_c(GL_TRIANGLES, $indices_size, GL_UNSIGNED_INT, $indices_oga->ptr);

        glDisableVertexAttribArrayARB($_) for(@enabled_attributes);
        $self->shader->Disable;
    };
    return $draw_function;
}

1;
