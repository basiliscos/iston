package Iston::Object;

use 5.12.0;

use Carp;
use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);


has ($_ => (is => 'rw', required => 0) )
    for(qw/x y z/);
has vertices => (is => 'ro', required => 1);
has indices  => (is => 'ro', required => 1);
has normals  => (is => 'ro', required => 1);
has mode     => (is => 'rw', default => sub { 'normal' }, trigger => 1);
has contexts => (is => 'rw', default => sub { {} });

has vertices_oga => (is => 'lazy');
has normals_oga  => (is => 'lazy');
has colors_oga   => (is => 'lazy');

method BUILD {
    my ($v_size, $n_size) = map { scalar(@{ $self->$_ }) }
        qw/vertices normals/;
    croak "Count of vertices must match count of normals"
        unless $v_size == $n_size;
    $self->_calculate_center;
}

my $_as_oga = sub {
    my $source = shift;
    return OpenGL::Array->new_list(
        GL_FLOAT,
        @$source
    );
};

method _calculate_center {
    my $first_vertex = [ @{ $self->vertices }[0..2] ];
    my ($mins, $maxs) = ([@$first_vertex ], [@$first_vertex]);
    my $vertices_count = scalar(@{$self->vertices})/3;
    for my $vertex_index (0 .. $vertices_count-1) {
        my @coords = @{ $self->vertices }
            [ $vertex_index*3 .. $vertex_index*3+2 ];
        for my $c(0 .. 2) {
            $mins->[$c] = $coords[$c] if($mins->[$c] > $coords[$c]);
            $maxs->[$c] = $coords[$c] if($maxs->[$c] < $coords[$c]);
        }
    }
    my @avgs = map { ($mins->[$_] + $maxs->[$_]) /2  } (0 .. 2);
    $self->x($avgs[0]);
    $self->y($avgs[1]);
    $self->z($avgs[2]);
}

method _build_vertices_oga {
    return $_as_oga->($self->vertices);
};

method _build_colors_oga {
    return $_as_oga->($self->colors);
};

method _build_normals_oga {
    return $_as_oga->($self->normals);
};

method _trigger_mode {
    my $mode = $self->mode;
    if ($mode eq 'mesh') {
       $self->contexts->{normal} = {
           indices => $self->indices,
       };
       $self->indices = $self->_triangle_2_lines_indices;
   }else {
       $self->contexts->{mesh} = {
           indices => $self->indices,
       };
       $self->indices = $self->contexts->{normal}->{indices};
   }
};

method _triangle_2_lines_indices {
    my $source = $self->indices;
    my ($number_of_points, $number_of_coordinates) = (3, 3);
    my $components = $number_of_points;
    my @result = map {
        my $idx = $_;
        my @v = @{$source}[$idx*3 .. $idx*3+2];
        my @r = @v[0,1,1,2,2,0];
        @r;
    } (0 .. scalar(@$source) / $components-1);
    return \@result;
}

method draw {
    #glEnable(GL_NORMALIZE);

    my $vertices = $self->vertices_oga;
    my $components = 3; # number of coordinates
    glEnableClientState(GL_NORMAL_ARRAY);
    glNormalPointer_p($self->normals_oga);
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer_p($components, $vertices);

    my $indices = $self->indices;
    my $indices_size = scalar(@$indices);
    my $mode = $self->mode;
    my $draw_mode = $mode eq 'normal'
        ? GL_TRIANGLES : GL_LINES;
    glDrawElements_s($draw_mode, $indices_size, GL_UNSIGNED_INT,
                     pack("L${indices_size}", @$indices));
}

1;
