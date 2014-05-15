use 5.12.0;

use Test::More;
use Test::Warnings;

use aliased qw/Iston::ObjLoader/;
use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

subtest "load cube" => sub {
    my $l = ObjLoader->new(file => 'share/models/cube.obj');
    my $c = $l->load;
    ok $c;

    is scalar(@{ $c->vertices }), 8;
    is_deeply $c->vertices->[0],
        Vertex->new([qw/1.000000 -1.000000 -1.000000/]);

    is scalar(@{ $c->indices }), 6*2*3; # every square = 2 triangles
    is_deeply [ @{$c->indices}[0..5] ],
        [qw/ 0 1 3
             4 7 5 /];

    is scalar(@{ $c->normals }), scalar(@{ $c->vertices });
    is_deeply $c->normals->[0],
        Vector->new([qw/0.577350 -0.577350 -0.577350/]);
};

done_testing;
