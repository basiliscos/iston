package Iston::Zone;

use 5.16.0;
use warnings;

use Iston::Matrix;
use Iston::Utils qw/rotation_matrix/;
use Math::Trig;
use Moo;

use aliased qw/Iston::Vertex/;

has xz => (is => 'ro', required => 1);
has yz => (is => 'ro', required => 1);

has spread => (is => 'rw', required => 1);
has active => (is => 'rw', default => sub { 0 });

has _transformation => (is => 'lazy');

sub _build__transformation {
    my ($self) = @_;
    my $rotate_xz = rotation_matrix(0, 1, 0, deg2rad($self->xz));
    my $rotate_yz = rotation_matrix(1, 0, 0, deg2rad($self->yz));
    my $m = $rotate_yz * $rotate_xz;
    return $m;
};

sub sphere_points {
    my ($self, $angle, $need_center) = @_;
    $need_center //= 1;
    my $center = Iston::Matrix->new_from_cols([ [0, 0, 1] ]);
    my $shifted_center = $self->_transformation * $center;
    my $shifted_center_vx = Vertex->new(values => [ map { $shifted_center->element($_, 1) } (1, 2, 3) ]);

    my $angle_rotation = rotation_matrix(@{ $shifted_center_vx->values }, deg2rad($angle));

    my $rotation_axis = $self->_transformation * Iston::Matrix->new_from_cols([ [-1, 0, 0] ]);
    my @rotation_coordinages = map { $rotation_axis->element($_, 1) } (1, 2, 3);
    my $spread = $self->spread;
    my $rotate_pos = rotation_matrix(@rotation_coordinages, deg2rad($spread/2));
    my $rotate_neg = rotation_matrix(@rotation_coordinages, deg2rad(-1 * $spread/2));

    my $pos_mx = $angle_rotation * $rotate_pos * $shifted_center;
    my $neg_mx = $angle_rotation * $rotate_neg * $shifted_center;

    my $pos_vx = Vertex->new(values => [ map { $pos_mx->element($_, 1) } (1, 2, 3) ]);
    my $neg_vx = Vertex->new(values => [ map { $neg_mx->element($_, 1) } (1, 2, 3) ]);

    return ($need_center ? ($shifted_center_vx): (), $pos_vx, $neg_vx);
}

1;
