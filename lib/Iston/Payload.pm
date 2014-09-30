package Iston::Payload;
# ABSTRACT: holds hash-ref with additional attirubtes for basic objects
$Iston::Payload::VERSION = '0.07';
use Moo::Role;

has payload => (is => 'ro', default => sub { {} });

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Payload - holds hash-ref with additional attirubtes for basic objects

=head1 VERSION

version 0.07

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
