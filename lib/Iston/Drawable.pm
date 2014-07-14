package Iston::Drawable;
$Iston::Drawable::VERSION = '0.04';
use 5.12.0;

use Moo::Role;

has rotation => (is => 'rw', default => sub { [0, 0, 0] });
has enabled => (is => 'rw', default => sub { 1 });

sub rotate {
    my ($self, $axis, $value) = @_;
    if (defined $value) {
        $self->rotation->[$axis] = $value;
    }
    else {
        return $self->rotation->[$axis];
    }
}

requires qw/draw_function/;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Drawable

=head1 VERSION

version 0.04

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
