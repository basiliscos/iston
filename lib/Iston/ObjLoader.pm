package Iston::ObjLoader;

use 5.12.0;

use Carp;
use List::MoreUtils qw/any uniq/;
use List::Util qw/reduce/;
use Function::Parameters qw(:strict);
use Moo;
use Path::Tiny;
use Smart::Comments -ENV;

use Iston::Utils qw/normalize/;

use aliased qw/Iston::Object/;

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
            push @vertices, @coordinates;
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
            push @normals, @coordinates;
        }
    }
    # converting normals for faces into normals for vertices
    my @vertices_normals;
    while (my ($v_index, $n_indices) = each(%normals_for_vertex)) {
        ### $v_index
        my @uniq_n_indices = uniq @$n_indices;
        ### @uniq_n_indices
        my $vertice_vector = reduce {
            ### $a
            ### $b
            [
                $a->[0] + $b->[0],
                $a->[1] + $b->[1],
                $a->[2] + $b->[2],
            ]
        } map { [@normals[ $_*3 .. $_*3+2]] }
            @uniq_n_indices;
        my $vertice_normal = normalize($vertice_vector);
        $vertices_normals[$v_index] = $vertice_normal;
    }
    # flatten vertices
    @vertices_normals = map { @$_ } map { $_ // [0, 0, 0] } @vertices_normals;

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
