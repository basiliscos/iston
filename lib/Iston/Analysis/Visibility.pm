package Iston::Analysis::Visibility;
# Abstract: Analyzes pixel colors to determine object(s) visibility

use 5.16.0;

use Carp;
use Function::Parameters qw(:strict);
use Iston::XS::Utils qw/find_uniq_pixels find_matching_pixels/;
use Moo;

has pattern        => (is => 'ro', required => 1);
has pattern_colors => (is => 'lazy');

method _build_pattern_colors {
    my $pattern = $self->pattern;
    my $bpp = $pattern->format->BytesPerPixel;
    croak "bytes per pixel != 4 for pattern" unless $bpp == 4;
    my $ptr = $pattern->get_pixels_ptr;
    my @interesting_colors = values %{ find_uniq_pixels($ptr) };
    say "found pattern colors on ",
        join(', ', map{ sprintf('%X', $_) } @interesting_colors );
    return \@interesting_colors;
};

method find ($image) {
    my $pix_buffer = $image->get_pixels_ptr;
    return find_matching_pixels($pix_buffer, $self->pattern_colors);
};

1;
