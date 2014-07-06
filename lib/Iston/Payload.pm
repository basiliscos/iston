package Iston::Payload;
# ABSTRACT: holds hash-ref with additional attirubtes for basic objects

use Moo::Role;

has payload => (is => 'ro', default => sub { {} });

1;
