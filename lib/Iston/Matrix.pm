package Iston::Matrix;
$Iston::Matrix::VERSION = '0.06';
use 5.16.0;

use parent qw/Math::MatrixReal/;

sub as_list {
    my $self = shift;
    my ($rows, $cols) = $self->dim;
    my @data;
    for my $i (1 .. $rows) {
        for my $j (1 .. $cols) {
            $data[($i-1)*$cols+($j-1)] = $self->element($i, $j);
        }
    }
    return @data;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Matrix

=head1 VERSION

version 0.06

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
