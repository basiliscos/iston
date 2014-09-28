package Iston::Object::HTM;
# Abstract: Hierarchical Triangular Map
$Iston::Object::HTM::VERSION = '0.06';
use 5.12.0;

use Carp;
use Iston::Utils qw/generate_list_id/;
use Iston::Vector qw/normal/;
use List::MoreUtils qw/first_index/;
use List::Util qw/max min reduce/;
use Math::Trig;
use Moo;
use Function::Parameters qw(:strict);
use OpenGL qw(:all);

use aliased qw/Iston::Triangle/;
use aliased qw/Iston::TrianglePath/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

# OK, let's calculate the defaults;
my $_R  = 1;

my $_vertices = [
    Vertex->new([0,  $_R, 0]), # top
    Vertex->new([0, -$_R, 0]), # bottom
    Vertex->new([$_R * sin(deg2rad 45) , 0, $_R * sin(deg2rad  45)]),  # front left
    Vertex->new([$_R * sin(deg2rad -45), 0, $_R * sin(deg2rad  45)]),  # front righ
    Vertex->new([$_R * sin(deg2rad -45), 0, $_R * sin(deg2rad -45)]),  # back right
    Vertex->new([$_R * sin(deg2rad 45) , 0, $_R * sin(deg2rad -45)]),  # back left
];

my $_indices = [
    0, 3, 2, # 0: north-front
    0, 4, 3, # 1: north-right
    0, 5, 4, # 2: north-back
    0, 2, 5, # 3: north-left
    1, 2, 3, # 4: south-front
    1, 3, 4, # 5: south-right
    1, 4, 5, # 6: south-back
    1, 5, 2, # 7: south-left
];

has level        => (is => 'rw', default => sub { 0  }, trigger => 1 );
has levels_cache => (is => 'ro', default => sub { {} } );
has triangles    => (is => 'rw', default =>
    sub {
        my @triangles =
            map {
                my @v_indices = ($_*3 .. $_*3+2);
                my @vertices =
                    map { $_vertices->[$_] }
                    map { $_indices->[$_] }
                    @v_indices;
                Triangle->new(
                    vertices    => \@vertices,
                    path        => TrianglePath->new($_),
                    tesselation => 1,
                );
            } (0 .. @$_indices/3 - 1);
        return \@triangles;
    } );

#has normals      => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );
#has vertices     => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );
#has indices      => (is => 'rw', lazy => 1, builder => 1, clearer => 1 );

has scale    => (is => 'rw', default => sub { 1; });

has draw_function => (is => 'lazy', clearer => 1);

with('Iston::Drawable');

method BUILD {
    $self->levels_cache->{$self->level} = $self->triangles;
    $self->_calculate_normals;
};


method _calculate_normals {
    my $triangles = $self->triangles;
    my %triangles_of;
    my %index_of_vertex;
    for my $t (@$triangles) {
        my $vertices = $t->vertices;
        for my $idx (0 .. @$vertices-1) {
            my $v = $vertices->[$idx];
            push @{$triangles_of{$v}}, $t;
            $index_of_vertex{$v}->{$t} = $idx;
        }
    }
    for my $v (keys %triangles_of) {
        my $avg =
            reduce { $a + $b }
            map { $_->normal }
            @{ $triangles_of{$v} };
        my $n = $avg->normalize;
        for my $t (@{ $triangles_of{$v} }) {
            my $v_idx = $index_of_vertex{$v}->{$t};
            $t->normals->[$v_idx] = $n;
        }
    }
}

method _trigger_level($level) {
    my $current_triangles = $self->triangles;
    for my $l (0 .. $level) {
        $self->levels_cache->{$l} //= do {
            my @triangles = map {
                @{ $_->subtriangles() }
            } @$current_triangles;
            \@triangles;
        };
        $current_triangles = $self->levels_cache->{$l};
    }
    $self->triangles($current_triangles);
    $self->_calculate_normals;
    $self->clear_draw_function;
}

method rotate($axis,$value = undef){
    if (defined $value) {
        for (@{ $self->triangles }) {
            $_->rotate($axis, $value);
        }
    }
    else {
        return $self->triangles->[0]->rotate($axis);
    }
}

method radius {
    return 1;
};

method _build_draw_function {
    my @triangles =
        grep { $_ && $_->enabled }
        @{ $self->triangles };
    my $scale = $self->scale;

    my ($id, $cleaner) = generate_list_id;
    glNewList($id, GL_COMPILE);
    $_->draw_function->() for(@triangles);
    glEndList;

    return sub {
        my $cleaner_ref = \$cleaner;
        glScalef($scale, $scale, $scale);
        glRotatef($self->rotate(0), 1, 0, 0);
        glRotatef($self->rotate(1), 0, 1, 0);
        glRotatef($self->rotate(2), 0, 0, 1);

        glCallList($id);
    };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Object::HTM

=head1 VERSION

version 0.06

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
