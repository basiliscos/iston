package Iston::Object;

use 5.12.0;

use Carp;
use Moo;
use List::Util qw/max/;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

with('Iston::Drawable');

has center   => (is => 'lazy');
has scale    => (is => 'rw', default => sub { 1; });
has vertices => (is => 'rw', required => 0);
has indices  => (is => 'rw', required => 0);
has normals  => (is => 'rw', required => 0);
has mode     => (is => 'rw', default => sub { 'normal' }, trigger => 1);
has contexts => (is => 'rw', default => sub { {} });
has cache    => (is => 'rw', default => sub { {} });

# material properties
has diffuse   => (is => 'rw', default => sub { [0.75, 0.75, 0.75, 1]} );
has ambient   => (is => 'rw', default => sub { [0.75, 0.75, 0.75, 1]} );
has specular  => (is => 'rw', default => sub { [0.8, 0.8, 0.8, 1.0]} );
has shininess => (is => 'rw', default => sub { 50.0 } );

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
   }else {
       $self->contexts->{mesh} = {
           indices => $self->indices,
       };
       $self->indices($self->contexts->{normal}->{indices});
   }
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
}

method draw {
    my $scale = $self->scale;
    if ($scale) {
        glScalef($scale, $scale, $scale);
        glRotatef($self->rotate(0), 1, 0, 0);
        glRotatef($self->rotate(1), 0, 1, 0);
        glRotatef($self->rotate(2), 0, 0, 1);
    }

    my $cache = $self->cache;
    my ($p_vertices, $p_normals) =
        map {
            my $v = $self->$_;
            croak "$_ is mandatory" if (!defined($v) or !@$v);
            $v;
        } qw/vertices normals/;
    my ($vertices, $normals) =
        map { $cache->{$_} //= $_as_oga->($_) }
        ($p_vertices, $p_normals);
    my $components = 3; # number of coordinates
    glEnableClientState(GL_NORMAL_ARRAY);
    glNormalPointer_p($normals);
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer_p($components, $vertices);

    # applying material properties to the whole object
    glMaterialfv_c(GL_FRONT, GL_DIFFUSE,   OpenGL::Array->new_list(
        GL_FLOAT, @{ $self->diffuse } )->ptr);
    glMaterialfv_c(GL_FRONT, GL_AMBIENT,   OpenGL::Array->new_list(
        GL_FLOAT, @{ $self->ambient } )->ptr);
    glMaterialfv_c(GL_FRONT, GL_SPECULAR,  OpenGL::Array->new_list(
        GL_FLOAT, @{ $self->specular} )->ptr);
    glMaterialfv_c(GL_FRONT, GL_SHININESS, OpenGL::Array->new_list(
        GL_FLOAT, $self->shininess)->ptr);

    my $indices = $self->indices;
    my $indices_size = scalar(@$indices);
    my $mode = $self->mode;
    my $draw_mode = $mode eq 'normal'
        ? GL_TRIANGLES : GL_LINES;

    glDrawElements_p($draw_mode, @$indices);
}

1;
