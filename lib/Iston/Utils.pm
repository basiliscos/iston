package Iston::Utils;

use 5.12.0;

use Guard;
use Function::Parameters qw(:strict);
use Iston::Matrix;
use List::Util qw/reduce/;
use Math::Trig;
use OpenGL qw(:all);

use aliased qw/Iston::Vector/;

use parent qw/Exporter/;

our @EXPORT = qw/maybe_zero rotation_matrix generate_list_id translate perspective
                 look_at identity rotate scale as_oga as_cartesian initial_vector/;

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

fun generate_list_id() {
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
    my $values = $vector->values;
    return Iston::Matrix->new_from_rows([
        [1, 0, 0, $values->[0]],
        [0, 1, 0, $values->[1]],
        [0, 0, 1, $values->[2]],
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

fun as_oga($source) {
    my $source = shift;
    return OpenGL::Array->new_list(
        GL_FLOAT,
        map { @{ ref eq 'ARRAY' ? $_ : $_->values } } @$source
    );
};


my $_identity = Iston::Matrix->new_from_rows([
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
]);

fun identity() {
    return $_identity;
};

my $_initial_point = [0, 0, 1];
my $_current_point =  Iston::Matrix->new_from_cols([ $_initial_point ]);

fun as_cartesian($dx, $dy) {

    # my $x_axis_degree = $dx * -1;
    # my $y_axis_degree = $dy * -1;
    # my $x_rads = deg2rad($x_axis_degree);
    # my $y_rads = deg2rad($y_axis_degree);
    # my $r_a = Iston::Matrix->new_from_rows([
    #     [1, 0,            0            ],
    #     [0, cos($x_rads), -sin($x_rads)],
    #     [0, sin($x_rads), cos($x_rads) ],
    # ]);
    # my $r_b = Iston::Matrix->new_from_rows([
    #     [cos($y_rads),  0, sin($y_rads)],
    #     [0,          ,  1, 0           ],
    #     [-sin($y_rads), 0, cos($y_rads)],
    # ]);
    # my $rotation = $r_b * $r_a; # reverse order!
    # my $result = $rotation * $_current_point;
    # my @xyz = map { $result->element($_, 1) } (1 .. 3);
    # return \@xyz;


    # simplified version of the above:

    my $da = deg2rad $dx;
    my $db = deg2rad $dy;
    my $cos_a = cos($da);
    my @values = (
        - $cos_a * sin($db),
        sin($da),
        cos($da) * cos($db),
    );
    return \@values;  # [ map { maybe_zero($_) } @values ];
};

1;
