package Iston::History::Record;
$Iston::History::Record::VERSION = '0.01';
use 5.12.0;

use Moo;

our @fields = qw/timestamp x_axis_degree y_axis_degree camera_x camera_y camera_z/;

for (@fields) {
    has $_ => (is => 'ro', required => 1);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::History::Record

=head1 VERSION

version 0.01

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>,

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
