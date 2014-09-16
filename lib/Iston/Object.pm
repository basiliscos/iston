package Iston::Object;

use 5.16.0;

use Carp;
use Iston::Matrix;
use Iston::Utils qw/generate_list_id identity/;
use Moo;
use List::Util qw/max/;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);
use OpenGL::Image;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;


has center       => (is => 'lazy');
has scale        => (is => 'rw', default => sub { 1; }, trigger => 1);
has vertices     => (is => 'rw', required => 0);
has indices      => (is => 'rw', required => 0);
has normals      => (is => 'rw', required => 0);
has uv_mappings  => (is => 'rw', required => 0);
has texture_file => (is => 'rw', required => 0);
has mode         => (is => 'rw', default => sub { 'normal' }, trigger => 1);
has contexts     => (is => 'rw', default => sub { {} });

has texture_id    => (is => 'lazy');
has draw_function => (is => 'lazy', clearer => 1);

# matrices
has model          => (is => 'rw', trigger => sub{ shift->clear_model_oga }, default => sub { identity; });
has model_scale    => (is => 'rw', trigger => sub{ shift->clear_model_oga }, default => sub { identity; });
has model_rotation => (is => 'rw', trigger => sub{ shift->clear_model_oga }, default => sub { identity; });
has model_oga      => (is => 'lazy', clearer => 1);

# material properties
has diffuse   => (is => 'rw', default => sub { [0.75, 0.75, 0.75, 1]} );
has ambient   => (is => 'rw', default => sub { [0.75, 0.75, 0.75, 1]} );
has specular  => (is => 'rw', default => sub { [0.8, 0.8, 0.8, 1.0]} );
has shininess => (is => 'rw', default => sub { 50.0 } );


with('Iston::Drawable');

method _trigger_rotation($values) {
    my $m = identity;
    for my $idx (0 .. @$values-1) {
        my $angle = $values->[$idx];
        if($angle) {
            my @axis_components = (0) x scalar(@$values);
            $axis_components[$idx] = 1;
            my $axis = Vector->new(\@axis_components);
            $m *= Iston::Utils::rotate($angle, $axis);
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
    my $rotation = $self->model_rotation;
    my $model = $self->model;
    my $matrix = $model * $rotation * $scale;
    $matrix = ~$matrix;
    return OpenGL::Array->new_list(GL_FLOAT, $matrix->as_list);
}

method _build_center {
    my ($v_size, $n_size) = map { scalar(@{ $self->$_ }) }
        qw/vertices normals/;
    croak "Count of vertices must match count of normals"
        unless $v_size == $n_size;

    my($mins, $maxs) = $self->boudaries;
    my @avgs = map { ($mins->[$_] + $maxs->[$_]) /2  } (0 .. 2);
    return Vertex->new(\@avgs);
};

my $_as_oga = sub {
    my $source = shift;
    return OpenGL::Array->new_list(
        GL_FLOAT,
        map { @$_ } @$source
    );
};

method boudaries {
    my $first_vertex = $self->vertices->[0];
    my ($mins, $maxs) = map { Vertex->new($first_vertex) } (0 .. 1);
    my $vertices_count = scalar(@{$self->vertices});
    for my $vertex_index (0 .. $vertices_count-1) {
        my $v = $self->vertices->[$vertex_index];
        for my $c (0 .. 2) {
            $mins->[$c] = $v->[$c] if($mins->[$c] > $v->[$c]);
            $maxs->[$c] = $v->[$c] if($maxs->[$c] < $v->[$c]);
        }
    }
    return ($mins, $maxs);
};

method radius {
    my $c = $self->center;
    my $r = max(
        map { $_->length }
        map { $c->vector_to($_) }
        @{ $self->vertices }
    );
    $r;
}

method translate($vector) {
    my $vertices_count = scalar(@{$self->vertices});
    for my $vertex_index (0 .. $vertices_count-1) {
        for my $c (0 .. 2) {
            $self->vertices->[$vertex_index]->[$c] += $vector->[$c];
        }
    };
    for my $c (0 .. 2) {
        $self->center->[$c] += $vector->[$c];
    }
}

method _trigger_mode {
    my $mode = $self->mode;
    if ($mode eq 'mesh') {
        $self->contexts->{normal} = {
            indices => $self->indices,
        };
        $self->indices($self->_triangle_2_lines_indices);
    } else {
        $self->contexts->{mesh} = {
            indices => $self->indices,
        };
        $self->indices($self->contexts->{normal}->{indices});
    }
    $self->clear_draw_function;
};

method _triangle_2_lines_indices {
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

method _build_texture_id {
    return if(!defined($self->uv_mappings) or !defined($self->texture_file));

    my ($texture_id) = glGenTextures_p(1);
    my $texture = OpenGL::Image->new( source => $self->texture_file);

    my($internan_format, $format, $type) = $texture->Get('gl_internalformat','gl_format','gl_type');
    my($texture_width, $texture_height) = $texture->Get('width','height');

    die ("texture isn't power of 2?") if (!$texture->IsPowerOf2());

    glBindTexture(GL_TEXTURE_2D, $texture_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D_c(GL_TEXTURE_2D, 0, $internan_format, $texture_width, $texture_height,
                   0, $format, $type, $texture->Ptr());

    return $texture_id;
}

method _build_draw_function {
    my $scale = $self->scale;

    my ($p_vertices, $p_normals) =
        map {
            my $v = $self->$_;
            croak "$_ is mandatory" if (!defined($v) or !@$v);
            $v;
        } qw/vertices normals/;
    my ($vertices, $normals) =
        map { $_as_oga->($_) }
        ($p_vertices, $p_normals);
    my $components = 3; # number of coordinates
    my ($vbo_vertices, $vbo_normals) = glGenBuffersARB_p(2);
    $vertices->bind($vbo_vertices);
    glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $vertices, GL_STATIC_DRAW_ARB);

    my $indices = $self->indices;
    my $indices_size = scalar(@$indices);
    my $mode = $self->mode;
    my $draw_mode = $mode eq 'normal'
        ? GL_TRIANGLES : GL_LINES;


    #$indices = [@{$indices}[0 .. 9] ];

    # my ($diffuse, $ambient, $specular) =  map {
    #     OpenGL::Array->new_list( GL_FLOAT, @$_ )
    #   } map { $self->$_ } qw/diffuse ambient specular/;
    # my $shininess = OpenGL::Array->new_list(GL_FLOAT, $self->shininess);
    my $draw_function = sub {
        my $shader = shift;
        # glEnableClientState(GL_NORMAL_ARRAY);
        # glNormalPointer_p($normals);
        # glEnableClientState(GL_VERTEX_ARRAY);
        # glVertexPointer_p($components, $vertices);

        # # applying material properties to the whole object
        # glMaterialfv_c(GL_FRONT, GL_DIFFUSE, $diffuse->ptr);
        # glMaterialfv_c(GL_FRONT, GL_AMBIENT, $ambient->ptr);
        # glMaterialfv_c(GL_FRONT, GL_SPECULAR, $specular ->ptr);
        # glMaterialfv_c(GL_FRONT, GL_SHININESS, $shininess->ptr);

        # glDrawElements_p($draw_mode, @$indices);

        # glDisableClientState(GL_NORMAL_ARRAY);
        # glDisableClientState(GL_VERTEX_ARRAY);

        $shader->SetMatrix(model => $self->model_oga);

        my $texture_id = $self->texture_id;
        if (defined $texture_id) {
            glActiveTextureARB(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, $texture_id);
            my $uniform_mytexture = $shader->Map('mytexture') // die("cannot map mytexture uniform");
            glUniform1iARB($uniform_mytexture, 0); # /*GL_TEXTURE*/

            my ($vbo_texcoords) = glGenBuffersARB_p(1);
            my $attribute_texcoord = $shader->MapAttr("texcoord");
            my $texcoords_oga = OpenGL::Array->new_list(
                GL_FLOAT, map { @$_ } @{ $self->uv_mappings }
            );
            $texcoords_oga->bind($vbo_texcoords);
            glBufferDataARB_p(GL_ARRAY_BUFFER_ARB, $texcoords_oga, GL_STATIC_DRAW_ARB);

            glEnableVertexAttribArrayARB($attribute_texcoord);
            #glBindBufferARB(GL_ARRAY_BUFFER, $texcoords_oga->bound);
            glVertexAttribPointerARB_c($attribute_texcoord, 2, GL_FLOAT, 0, 0, 0);
        }

        my $attribute_coord3d = $shader->MapAttr("coord3d");
        die ("cannot map coord3d attribute") unless defined $attribute_coord3d;
        glEnableVertexAttribArrayARB($attribute_coord3d);
        glBindBufferARB(GL_ARRAY_BUFFER, $vertices->bound);
        glVertexAttribPointerARB_c($attribute_coord3d, 3, GL_FLOAT, 0, 0, 0);

        # glEnableVertexAttribArrayARB($attribute_v_color);
        # glBindBufferARB(GL_ARRAY_BUFFER, $colors_oga->bound);
        # glVertexAttribPointerARB_c($attribute_v_color, 3, GL_FLOAT, 0, 0, 0);

        glDrawElements_p(GL_TRIANGLES, @$indices);

        glDisableVertexAttribArrayARB($attribute_coord3d);
        #glDisableVertexAttribArrayARB($attribute_v_color);
    };
    return $draw_function;
    # if ($self->display_list) {
    #     my ($id, $cleaner) = generate_list_id;
    #     glNewList($id, GL_COMPILE);
    #     $draw_function->();
    #     glEndList;
    #     $draw_function = sub {
    #         my $cleaner_ref = \$cleaner;
    #         glCallList($id);
    #     };
    # }
    # return sub {
    #     if ($scale) {
    #         glScalef($scale, $scale, $scale);
    #         glRotatef($self->rotate(0), 1, 0, 0);
    #         glRotatef($self->rotate(1), 0, 1, 0);
    #         glRotatef($self->rotate(2), 0, 0, 1);
    #     }
    #     $draw_function->();
    # };
}

1;
