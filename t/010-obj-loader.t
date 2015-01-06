use 5.12.0;

use List::MoreUtils qw/any/;
use Test::More;
use Test::Warnings;

use aliased qw/Iston::Loader/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

plan skip_all => "pdfToolbox isn't found in PATH"
    unless -e 'share/models';

sub _check_indices {
    my ($indices, $v_count) = @_;

    ok defined($_), "index defined"
        for(@$indices);

    for my $v_idx (0 .. $v_count - 1){
        my $has_vertex = any { $_ == $v_idx } @$indices;
        ok $has_vertex, "has vertex $v_idx in indices";
    }
};

subtest "load cube" => sub {
    my $l = Loader->new(file => 'share/models/cube.obj');
    my $c = $l->load;
    ok $c;

    is scalar(@{ $c->vertices }), 26;
    is_deeply $c->vertices->[0],
        Vertex->new(values => [qw/1.000000 -1.000000 -1.000000/]);

    is scalar(@{ $c->indices }), 6*2*3; # every square = 2 triangles

    is scalar(@{ $c->normals }), scalar(@{ $c->vertices });
    is $c->normals->[0], "vector[0.0000, -1.0000, 0.0000]";
    _check_indices($c->indices, 26);

    ok $c->radius - sqrt(1+1+1) < 0.0001, "got correct radius";
};

subtest "load two-squares" => sub {
    my $o = Loader->new(file => 'share/models/two-squares.obj')->load;
    ok $o;
    like $o->texture_file, qr/two-squares.png$/;

    my $indices = $o->indices;
    my $faces_count = @{$indices} / 3;
    is $faces_count, 2 * 2; # every square = 2 triangles

    my ($vertices_count, $uv_mappings_count) =
        map { scalar(@{ $o->$_ }) } qw/vertices uv_mappings/;
    is $vertices_count, 8;

    _check_indices($indices, $vertices_count);

    is $vertices_count, $uv_mappings_count,
        "number of UV-mappings equals to number of vertices";

    my ($v_min, $v_max) = map { $o->boundaries->[$_] } (0, 1);
    is $v_min, "vertex[-1.0000000, -1.0000000, -1.0000000]";
    is $v_max, "vertex[1.0000000, 1.0000000, 1.0000000]";

};

done_testing;
