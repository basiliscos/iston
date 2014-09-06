package Iston::Vertex;
$Iston::Vertex::VERSION = '0.05';
use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);

use aliased qw/Iston::Vector/;

use overload
    '""' => '_stringify',
     fallback => 1,
   ;

sub new {
    my ($class, $values) = @_;
    croak "Vertex is defined exactly by 3 values"
        unless @$values == 3;

    my $copy = [@$values];
    bless $copy => $class;
};

method vector_to($vertex_b) {
    my ($a, $b) = ($self, $vertex_b);
    my @values = map { $b->[$_] - $a->[$_] } (0 .. 2);
    return Vector->new(\@values);
};

sub _stringify {
    my $self = shift;
    return sprintf('vertex[%0.7f, %0.7f, %0.7f]', @{$self}[0 .. 2]);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Vertex

=head1 VERSION

version 0.05

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
