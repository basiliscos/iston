package Iston::ObjLoader;

use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use Moo;
use Path::Tiny;

use aliased qw/Iston::Object/;

has 'file' => (is => 'ro', required => 1);

method load {
    my @lines = path($self->file)->lines;

    my @vertices;
    my @indices;
    for my $line (@lines) {
        if ($line =~ /^v (.+)$/) {
            my @coordinates = split(/\s+/, $1);
            croak "There should be exactly 3 coordinates for vertex: $line"
                unless @coordinates == 3;
            push @vertices, @coordinates;
        } elsif ($line =~ /^f (.+)$/) {
            my @components = split(/\s+/, $1);
            croak "There should be exactly 3 components for face: $line"
                unless @components == 3;
            my @triangle_indices =
                map { $_-1 }
                map {
                    (split('/'))[0]
                } @components;
            push @indices, @triangle_indices;
        }
    }

    my $object = Object->new(
        vertices => \@vertices,
        indices  => \@indices,
    );

    return $object;
};

1;
