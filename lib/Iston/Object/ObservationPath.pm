package Iston::Object::ObservationPath;

use 5.12.0;

use Function::Parameters qw(:strict);
use Moo;
use Math::MatrixReal;

use aliased qw/Iston::Vertex/;

with('Iston::Drawable');

my $_PI = 2*atan2(1,0);
my $_G2R = $_PI / 180;

has history  => (is => 'ro', required => 1);
has scale    => (is => 'rw', default => sub { 1; });
has vertices => (is => 'rw');
has indices  => (is => 'rw');

method BUILD {
    $self->_build_vertices_and_indices;
}

method _build_vertices_and_indices {
    my $history = $self->history;
    my $base =  Math::MatrixReal->new_from_rows([ [0], [0], [1] ]);
    my @vertices;
    my @indices;
    for my $i (0 .. $history->elements-1) {
        my $record = $history->records->[$i];
        my ($alpha, $beta) = map { $record->$_ } qw/alpha beta/;
        my $r_a = Math::MatrixReal->new_from_rows([
            [1, 0,                 0                 ],
            [0, cos($alpha*$_G2R), -sin($alpha*$_G2R)],
            [0, sin($alpha*$_G2R), cos($alpha*$_G2R) ],
        ]);
        my $r_b = Math::MatrixReal->new_from_rows([
            [cos($beta*$_G2R),  0, sin($beta*$_G2R)],
            [0,              1, 0                  ],
            [-sin($beta*$_G2R), 0, cos($beta*$_G2R)],
        ]);
        my $rotation = $r_a * $r_b;
        my $result = $rotation * $base;
        my ($x, $y, $z) = map { $result->element($_, 1) } (1 .. 3);
        my $v = Vertex->new([$x, $y, $z]);
        push @vertices, $v;
        push @indices, $i-1, $i if($i);
    }
    $self->vertices(\@vertices);
    $self->indices(\@indices);
}

method draw {
    my $scale = $self->scale;
    glScalef($scale, $scale, $scale);
}

1;
