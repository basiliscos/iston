package Iston::Drawable;

use 5.12.0;

use Moo::Role;

has enabled => (is => 'rw', default => sub { 1 });
requires qw/draw/;

1;
