package Iston::Loader;
$Iston::Loader::VERSION = '0.02';
use 5.12.0;

use Carp;
use List::MoreUtils qw/any uniq/;
use List::Util qw/reduce/;
use Function::Parameters qw(:strict);
use Moo;
use Path::Tiny;
use Smart::Comments -ENV;

use aliased qw/Iston::Object/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'file' => (is => 'ro', required => 1);

method load {
    my @lines = path($self->file)->lines;

    my @vertices;
    my @indices;
    my @normals; # for faces
    my @normal_indices;
    my %normals_for_vertex; # key: vertex index, value: array of normal indices
    for my $line (@lines) {
        if ($line =~ /^v (.+)$/) {
            my @coordinates = split(/\s+/, $1);
            croak "There should be exactly 3 coordinates for vertex: $line"
                unless @coordinates == 3;
            push @vertices, Vertex->new(\@coordinates);
        } elsif ($line =~ /^f (.+)$/) {
            my @components = split(/\s+/, $1);
            croak "There should be exactly 3 components for face: $line"
                unless @components == 3;
            for my $c (@components) {
                my ($vertex_index, $texture_index, $normal_index) =
                    split('/', $c);
                push @indices, $vertex_index-1;
                push @{ $normals_for_vertex{$vertex_index-1} },
                    $normal_index-1;
            }
        } elsif ($line =~ /^vn (.+)$/) {
            my @coordinates = split(/\s+/, $1);
            croak "There should be exactly 3 coordinates for normal: $line"
                unless @coordinates == 3;
            push @normals, Vector->new(\@coordinates);
        }
    }
    # converting normals for faces into normals for vertices
    my @vertices_normals;
    while (my ($v_index, $n_indices) = each(%normals_for_vertex)) {
        ### $v_index
        my @uniq_n_indices = uniq @$n_indices;
        ### @uniq_n_indices
        my $vertice_vector =
            reduce {$a + $b }
            map { $normals[ $_ ] }
            @uniq_n_indices;
        my $vertice_normal = $vertice_vector->normalize;
        $vertices_normals[$v_index] = $vertice_normal;
    }
    # flatten vertices
    @vertices_normals = map { $_ // Vector->new([0, 0, 0]) } @vertices_normals;

    my $object = Object->new(
        vertices => \@vertices,
        indices  => \@indices,
        normals  => \@vertices_normals,
    );
    my $center = $object->center;
    my $to_center = [ map { $_ * -1 } @$center ];
    $object->translate($to_center);

    return $object;
};

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Loader

=head1 VERSION

version 0.02

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
