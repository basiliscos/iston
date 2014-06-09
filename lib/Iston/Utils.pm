package Iston::Utils;

use 5.12.0;

use parent qw/Exporter/;

our @EXPORT = qw/maybe_zero/;

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

1;
