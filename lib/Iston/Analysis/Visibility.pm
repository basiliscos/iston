package Iston::Analysis::Visibility;
# Abstract: Tracks the (angle) direction changes of the observation path

use 5.16.0;

use Carp;
use Function::Parameters qw(:strict);
use List::MoreUtils qw/any uniq/;
use Moo;

has pattern         => (is => 'ro', required => 1);
has pattern_colors => (is => 'lazy');

method _build_pattern_colors {
    my $pattern = $self->pattern;
    my $bpp = $pattern->format->BytesPerPixel;
    croak "bytes per pixel != 4 for pattern" unless $bpp == 4;
    my @interesting_colors =
        sort {$a <=> $b}
        uniq unpack('L*', ${ $pattern->get_pixels_ptr });
    say "found pattern colors on ",
        join(', ', map{ sprintf('%X', $_) } @interesting_colors );
    return \@interesting_colors;
};

method find ($image) {
    my $pix_buffer = $image->get_pixels_ptr;
    my @uniq_pixels = uniq unpack('L*', $$pix_buffer );
    my @matched_colors;
    for my $color (@{ $self->pattern_colors }) {
        if (any {$_ eq $color} @uniq_pixels) {
            #say "Found color: ", sprintf('%x', $color), " on step $s";
            push @matched_colors, $color;
        }
    }
    return \@matched_colors;
};

1;
