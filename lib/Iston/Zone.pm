package Iston::Zone;

use 5.16.0;
use warnings;

use Iston::Matrix;
use Iston::Utils qw/rotation_matrix/;
use Math::Trig;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has xz => (is => 'ro', required => 1);
has yz => (is => 'ro', required => 1);

has spread => (is => 'rw', required => 1);
has active => (is => 'rw', default => sub { 0 });

has _transformation => (is => 'lazy');

sub as_hash {
    my ($self) = @_;
    return {
        map { $_ => $self->$_ } qw/xz yz spread/
    };
}

sub _build__transformation {
    my ($self) = @_;
    my $rotate_xz = rotation_matrix(0, -1, 0, deg2rad($self->xz));
    my $rotate_yz = rotation_matrix(-1, 0, 0, deg2rad($self->yz));
    my $m = $rotate_xz * $rotate_yz;
    return $m;
};

sub center {
    my $self = shift;
    my $center = Iston::Matrix->new_from_cols([ [0, 0, 1] ]);
    my $center_m = $self->_transformation * $center;
    return _as_vertex($center_m);
}

sub _as_vertex {
    my $m = shift;
    return Vertex->new(values => [map {$m->element($_, 1)} (1, 2, 3)]);
}

sub sphere_points {
    my ($self, $angle, $need_center) = @_;
    $need_center //= 1;

    my $spread = $self->spread;
    my $center = Iston::Matrix->new_from_cols([ [0, 0, 1] ]);
    my $angle_rotation = rotation_matrix(0, 0, 1, deg2rad($angle));

    my $v1 = $angle_rotation * rotation_matrix(-1, 0, 0, deg2rad($spread/2)) * $center;
    my $v2 = $angle_rotation * rotation_matrix(-1, 0, 0, deg2rad(-1 * $spread/2)) * $center;

    my $t = $self->_transformation;
    ($center, $v1, $v2) = map { $t * $_ } ($center, $v1, $v2);

    my $as_vertex = \&_as_vertex;
    my $c_vx = $center->$as_vertex;
    my $pos_vx = $v1->$as_vertex;
    my $neg_vx = $v2->$as_vertex;

    return ($need_center ? ($c_vx): (), $pos_vx, $neg_vx);
}

1;
