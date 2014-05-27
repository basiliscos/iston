package Iston::History::Record;

use 5.12.0;

use Moo;

our @fields = qw/timestamp alpha beta camera_x camera_y camera_z/;

for (@fields) {
    has $_ => (is => 'ro', required => 1);
}

1;
