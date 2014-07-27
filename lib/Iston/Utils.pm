package Iston::Utils;

use 5.12.0;

use Guard;
use Function::Parameters qw(:strict);
use Math::MatrixReal;
use Math::Trig;
use OpenGL qw(:all);

use parent qw/Exporter/;

our @EXPORT = qw/maybe_zero rotation_matrix generate_list_id/;

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
    my $rotation = Math::MatrixReal->new_from_rows([
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
}

1;
