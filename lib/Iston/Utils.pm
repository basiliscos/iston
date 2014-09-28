package Iston::Utils;
$Iston::Utils::VERSION = '0.06';
use 5.12.0;

use Guard;
use Function::Parameters qw(:strict);
use Iston::Matrix;
use List::Util qw/reduce/;
use Math::Trig;
use OpenGL qw(:all);

use parent qw/Exporter/;

our @EXPORT = qw/maybe_zero rotation_matrix generate_list_id translate perspective
                 look_at identity rotate scale/;

my $_accuracy_format = '%0.6f';
my $_accuracy_zero   = sprintf($_accuracy_format, 0);

sub maybe_zero($) {
    my $value = shift;
    my $result;
    if (defined $value) {
        my $rounded = sprintf($_accuracy_format, abs($value));
        $result = $rounded eq $_accuracy_zero ? 0 : $value;;
    };
    return $result;
}

fun rotation_matrix($x, $y, $z, $f) {
    my $cos_f = cos($f);
    my $sin_f = sin($f);
    my $rotation = Iston::Matrix->new_from_rows([
        [$cos_f+(1-$cos_f)*$x**2,    (1-$cos_f)*$x*$y-$sin_f*$z, (1-$cos_f)*$x*$z+$sin_f*$y ],
        [(1-$cos_f)*$y*$z+$sin_f*$z, $cos_f+(1-$cos_f)*$y**2 ,   (1-$cos_f)*$y*$z-$sin_f*$x ],
        [(1-$cos_f)*$z*$x-$sin_f*$y, (1-$cos_f)*$z*$y+$sin_f*$x, $cos_f+(1-$cos_f)*$z**2    ],
    ]);
    return $rotation;
};

fun generate_list_id {
    my $id = glGenLists(1);
    my $cleaner = guard {
        say "deleting list $id";
        glDeleteLists($id, 1);
        say "list $id has been deleted";
    };
    return ($id, $cleaner);
};

fun rotate($angle, $axis) {
    my ($x, $y, $z) = @$axis;
    my $f = $angle;
    my $cos_f = cos(deg2rad($f));
    my $sin_f = sin(deg2rad($f));
    my $rotation = Iston::Matrix->new_from_rows([
        [$cos_f+(1-$cos_f)*$x**2,    (1-$cos_f)*$x*$y-$sin_f*$z, (1-$cos_f)*$x*$z+$sin_f*$y, 0 ],
        [(1-$cos_f)*$y*$z+$sin_f*$z, $cos_f+(1-$cos_f)*$y**2 ,   (1-$cos_f)*$y*$z-$sin_f*$x, 0 ],
        [(1-$cos_f)*$z*$x-$sin_f*$y, (1-$cos_f)*$z*$y+$sin_f*$x, $cos_f+(1-$cos_f)*$z**2    ,0 ],
        [0,                          0,                          0,                          1 ],
    ]);
    return $rotation;
}

fun scale($v) {
    return Iston::Matrix->new_from_rows([
        [$v, 0,  0,  0],
        [0,  $v, 0,  0],
        [0,  0,  $v, 0],
        [0,  0,  0,  1],
    ]);
}

fun translate($vector) {
    return Iston::Matrix->new_from_rows([
        [1, 0, 0, $vector->[0]],
        [0, 1, 0, $vector->[1]],
        [0, 0, 1, $vector->[2]],
        [0, 0, 0, 1],
    ]);
};

fun perspective($fov, $aspect, $z_near, $z_far){
    my $f = cot($fov / 2.0);
    return Iston::Matrix->new_from_rows([
        [$f/$aspect, 0, 0, 0],
        [0, $f, 0, 0],
        [0, 0, ($z_near + $z_far) / ($z_near - $z_far), 2*($z_near * $z_far) / ($z_near - $z_far)],
        [0, 0, -1, 0],
    ]);
};

fun look_at($eye, $at, $up){
    my $z_axis = ($eye - $at)->normalize;
    my $x_axis = ($up * $z_axis)->normalize;
    my $y_axis = $z_axis * $x_axis;
    return Iston::Matrix->new_from_rows([
        [@$x_axis, -($x_axis->scalar_multiplication($eye)) ],
        [@$y_axis, -($y_axis->scalar_multiplication($eye)) ],
        [@$z_axis, -($z_axis->scalar_multiplication($eye)) ],
        [0, 0, 0, 1]
    ]);
}

my $_identity = Iston::Matrix->new_from_rows([
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
]);

fun identity {
    return $_identity;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Utils

=head1 VERSION

version 0.06

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
