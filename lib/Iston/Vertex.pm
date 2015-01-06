package Iston::Vertex;
$Iston::Vertex::VERSION = '0.10';
use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::Utils qw/as_cartesian/;
use Moo;

use aliased qw/Iston::Vector/;

use overload
    '""' => '_stringify',
     fallback => 1,
   ;

with('Iston::Payload');

has 'values' => (is => 'ro', required => 1);

method vector_to($vertex_b) {
    my ($a, $b) = map {$_->values} ($self, $vertex_b);
    my @values = map { $b->[$_] - $a->[$_] } (0 .. 2);
    return Vector->new(values => \@values);
};

sub _stringify {
    my $values = shift->values;
    return sprintf('vertex[%0.7f, %0.7f, %0.7f]', @$values);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Vertex

=head1 VERSION

version 0.10

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
