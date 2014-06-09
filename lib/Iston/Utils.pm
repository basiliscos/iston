package Iston::Utils;
$Iston::Utils::VERSION = '0.02';
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Utils

=head1 VERSION

version 0.02

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
