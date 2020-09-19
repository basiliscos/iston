package Iston::Object::MarkerContainer;

use 5.16.0;
use warnings;

use Function::Parameters qw(:strict);
use Math::Trig;
use Moo;
use List::Util qw/all/;
use OpenGL qw(:all);
use Iston::Utils qw/as_oga maybe_zero/;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has draw_function  => (is => 'lazy', clearer => 1);
has name           => (is => 'rw', default => sub { "markers-1" });
has zones          => (is => 'ro', default => sub { [] });
has current_point  => (is => 'ro');
has results        => (is => 'lazy');
has last_distances => (is => 'rw');

with('Iston::Drawable');

method has_texture() { return 0; };

sub BUILD {
    my $self = shift;
    $self->notifyer->declare('zone_distances_change');
    $self->notifyer->subscribe('view_change' => sub { $self->calc_distances($self->current_point->() ); });
}

sub as_hash {
    my ($self) = @_;
    return {
        name  => $self->name,
        zones =>  [ map { $_->as_hash }@{ $self->zones }],
    };
}

my $_center = Vertex->new(values => [0, 0, 0]);

sub calc_distances {
    my ($self, $point) = @_;
    my $end = $_center->vector_to($point);
    my @r;
    my $zones = $self->zones;
    for my $z_idx (0 .. @$zones - 1) {
        my $start = $_center->vector_to($zones->[$z_idx]->center);
        my $angle = $start->angle_with($end);
        push @r, $angle;
    }
    $self->last_distances(\@r);
    $self->notifyer->publish('zone_distances_change' => \@r);
    return \@r;
}

sub dump_analisys {
    my ($self, $fh, $observation_path) = @_;
    my $vectors = $observation_path->sphere_vectors->vectors;
    my $results;
    my $zones = $self->zones;
    for my $z_index (0 .. @$zones-1) {
        my $z = $zones->[$z_index];
        my ($z_center, $z_right, $z_left) = $z->sphere_points(90, 1);
        my $v_center = Vector->new(values => $z_center->values);
        for my $v_index (0 .. @$vectors-1) {
            my $v = $vectors->[$v_index];
            my $n = $v->payload->{great_arc_normal};
            my ($start, $end) = map { $v->payload->{$_} } qw/start_vertex end_vertex/;
            my $distance = rad2deg $v_center->angle_with(Vector->new(values => $end->values));
            $results->[$v_index][$z_index]{distance} = $distance;
            my $start_angle = $v_center->angle_with(Vector->new(values => $start->values));
            my $deviation;
            if (!$start_angle) {
                $deviation = 0;
            } else {
                my $n_zone = $z_right->vector_to($z_left) * $v_center;
                $deviation = rad2deg $n_zone->angle_with($n);
            }
            $results->[$v_index][$z_index]{deviation} = $deviation;
        }
    }

    # dump results
    my $vertices = $observation_path->vertices;
    my $v2s = $observation_path->vertex_to_sphere_index;
    my $mapper = $observation_path->sphere_vectors->vertex_to_vector_function;
    my $header = "vertex_index, " . join(", ", map { "distance_${_}, deviation_${_}" } (1 .. @$zones));
    say $fh $header;
    for my $idx (0 .. @$vertices -1) {
        my $sphere_index = $v2s->[$idx];
        my $vector_index = $mapper->($idx) // 0;
        my @line_values = ($idx);
        for my $z_index (0 .. @$zones-1) {
            my $values = $results->[$vector_index][$z_index];
            my @values = ($idx && $v2s->[$idx-1] != $sphere_index)
                ? map { $values->{$_}} qw/distance deviation/
                : (0, 0)
                ;
            push @line_values, map { sprintf('%0.2f', $_) } @values;
        }
        my $line = join(', ', @line_values);
        say $fh $line;
    }
    return $results;
}

method _build_draw_function() {
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
