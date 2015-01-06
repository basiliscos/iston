use 5.20.0;
use warnings;

use Iston::Utils qw/as_cartesian maybe_zero/;
use Math::Trig qw/spherical_to_cartesian acos_real rad2deg deg2rad/;

my $s2c = sub {
    my ($theta, $phi) = @_;
    my $sin_theta = sin($theta);
    my $x = $sin_theta * cos($phi);
    my $y = $sin_theta * sin($phi);
    my $z = cos($theta);
    return ($x, $y, $z);
};

my $_e = sub {
    my ($dx, $dy) = @_;
    my $caresian = as_cartesian($dx, $dy, 0);
    my ($x, $y, $z) = map { maybe_zero($_) } @$caresian;

    my $theta = rad2deg acos_real($z);
    my $phi   = rad2deg atan2($y,$x);
    say '=' x 50;
    say "dx = $dx, dy = $dy, x = $x, y = $y, z = $z, theta = $theta, phi = $phi";

    my $theta2 = rad2deg acos_real(cos(deg2rad $dx) * cos(deg2rad $dy));
    my $phi2 = rad2deg atan2( sin(deg2rad $dx), -1 * sin(deg2rad $dy) * cos(deg2rad $dx) );
    say "theta2 = $theta2,(", $theta2 == $theta, ") phi2 = $phi2, (", ($phi eq $phi2), ")";

    my ($nx, $ny, $nz) = map { maybe_zero($_) } $s2c->(deg2rad($theta2), deg2rad($phi2));
    say " nx = $nx ", ($nx == $x ? '(OK)' : '!'),
        " ny = $ny ", ($ny == $y ? '(OK)' : '!'),
        " nz = $nz ", ($nz == $z ? '(OK)' : '!')
        ;
};

$_e->(0, 0);
$_e->(90, 0);
$_e->(180, 0);
$_e->(270, 0);
$_e->(360, 0);
$_e->(0, 90);
$_e->(0, -90);
$_e->(90, -90);
say "...";
$_e->(0, 90);
$_e->(90, 90);
$_e->(90, 180);
#$_e->(-90, 180);
