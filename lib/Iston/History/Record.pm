package Iston::History::Record;

use 5.12.0;

use Moo;

our @fields = qw/timestamp x_axis_degree y_axis_degree camera_x camera_y camera_z label/;

for (@fields) {
    has $_ => (is => 'ro', required => 0);
}

1;
