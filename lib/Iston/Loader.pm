package Iston::Loader;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::Utils qw/translate/;
use List::MoreUtils qw/any uniq/;
use List::Util qw/reduce/;
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
    my @initial_v_indices;
    my @normals; # for faces
    my @normal_indices;
    my @uv_mappings;
    my @faces;
    my %info_for_vertex;
    my %order_for;
    my ($v_min, $v_max);
    for my $line (@lines) {
        if ($line =~ /^v (.+)$/) {
            my @coordinates = split(/\s+/, $1);
            croak "There should be exactly 3 coordinates for vertex: $line"
                unless @coordinates == 3;
            my $vertex = Vertex->new(\@coordinates);
            push @vertices, $vertex;

            # calculate boundaries
            $v_min //= Vertex->new([@coordinates]);
            $v_max //= Vertex->new([@coordinates]);
            for my $idx ( 0 .. @coordinates - 1) {
                $v_min->[$idx] = $coordinates[$idx] if $v_min->[$idx] > $coordinates[$idx];
                $v_max->[$idx] = $coordinates[$idx] if $v_max->[$idx] < $coordinates[$idx];
            }
        } elsif ($line =~ /^f (.+)$/) {
            my @components = split(/\s+/, $1);
            croak "There should be exactly 3 components for face: $line"
                unless @components == 3;
            for my $c (@components) {
                my ($vertex_index, $texture_index, $normal_index) =
                    split('/', $c);
                my $face_info = {
                    n => $normal_index,
                    t => $texture_index,
                    v => $vertex_index,
                };
                my $face_count = push @faces, $face_info;
                push @{ $info_for_vertex{$vertex_index-1}->{faces} },
                    $face_count-1;
                push @{ $info_for_vertex{$vertex_index-1}->{normals} },
                    $normal_index-1;
                push @{ $info_for_vertex{$vertex_index-1}->{textures} }, $texture_index -1
                    if $texture_index;

            }
        } elsif ($line =~ /^vn (.+)$/) {
            my @coordinates = split(/\s+/, $1);
            croak "There should be exactly 3 coordinates for normal: $line"
                unless @coordinates == 3;
            push @normals, Vector->new(\@coordinates);
        } elsif ($line =~ /^vt (.+)$/) {
            my @components = split /\s+/, $1;
            croak "There should be exactly 2 components for texture: $line"
                unless @components == 2;
            $components[1] = 1 - $components[1]; # (0,0) will become top-left corner
            push @uv_mappings, \@components;
        }
    }

    my @final_vertices;
    my @vertices_normals;
    my @vertices_mappings;
    my @new_incides;
    my %processed_vertex;
    my %new_index_for;

    my @vertex_incides;
    my @face_indices;
    for my $face_idx (0 .. @faces-1) {
        my $face_info = $faces[$face_idx];
        my $source_idx = $face_info->{v} - 1;
        my $info = $info_for_vertex{$source_idx};
        my ($f_indices, $n_indices, $t_indices) =  map { $info->{$_} } qw/faces normals textures/;
        my ($n, $t) = (-1, -1);
        for my $j (0 .. @$n_indices-1) {
            my $key = sub {
                my ($n, $t) = ($_[0], $_[1] // '?');
                return join("-", $source_idx, $n, $t);
            };
            my ($n_new, $t_new, $f_idx) = ($n_indices->[$j], $t_indices->[$j], $f_indices->[$j]);
            my $key_string = $key->($n_new, $t_new);
            my $insert_condition = ($n != $n_new or (defined $t and $t != $t_new))
                && (!exists $processed_vertex{$key_string});
            if ($insert_condition) {
                ($n, $t) = ($n_new, $t_new);
                push @vertices_normals, $normals[$n];
                push @vertices_mappings, $uv_mappings[$t] if(defined $t);
                push @final_vertices, Vertex->new($vertices[$source_idx]); # use copy!
                my $new_index = @final_vertices - 1;
                $processed_vertex{$key_string} = $new_index;
            }
            $face_indices[$f_idx] = $processed_vertex{$key_string};
        }
    }

    my $texture_file;
    if (@uv_mappings) {
        ($texture_file = path($self->file)) =~ s/(\.obj)$/.png/;
        $texture_file = undef unless -s $texture_file;
    }
    my $boundaries = [$v_min, $v_max];
    my $object = Object->new(
        vertices     => \@final_vertices,
        indices      => \@face_indices,
        normals      => \@vertices_normals,
        uv_mappings  => \@vertices_mappings,
        display_list => 1,
        boundaries   => $boundaries,
        (defined $texture_file ? (texture_file => $texture_file) : ()),
    );
    my $center = $object->center;
    my $to_center = -1 * Vector->new([@$center]);
    say "Shifting object $to_center";
    $object->model_translate(translate($to_center));
    # hack, this should be recalculated indirectly via matrices
    for (0 .. @$boundaries-1) {
        Vertex->new([ @{ $boundaries->[$_] + $to_center } ]);
    }
    return $object;
};

1;
