package Iston::Analysis::Visibility;
# Abstract: Tracks the (angle) direction changes of the observation path
$Iston::Analysis::Visibility::VERSION = '0.08';
use 5.16.0;

use Carp;
use Function::Parameters qw(:strict);
use Inline qw/C/;
use List::MoreUtils qw/any uniq/;
use Moo;

has pattern         => (is => 'ro', required => 1);
has pattern_colors => (is => 'lazy');

method _build_pattern_colors {
    my $pattern = $self->pattern;
    my $bpp = $pattern->format->BytesPerPixel;
    croak "bytes per pixel != 4 for pattern" unless $bpp == 4;
    my $ptr = $pattern->get_pixels_ptr;
    my $interesting_colors = _extract_pattern_xs($ptr);
    say "found pattern colors on ",
        join(', ', map{ sprintf('%X', $_) } @$interesting_colors );
    return $interesting_colors;
};

sub _extract_pattern_pp {
    my ($ptr) = @_;
    my @interesting_colors =
        sort {$a <=> $b}
        uniq unpack('L*', $$ptr);
    return \@interesting_colors;
}

sub _extract_pattern_xs {
    my ($ptr) = @_;
    my $found_colors = _extract_pattern($ptr);
    return [values(%$found_colors)];
}

method find ($image) {
    my $pix_buffer = $image->get_pixels_ptr;
    # return _find_colors_pp($pix_buffer, $self->pattern_colors);
    return _find_colors_xs($pix_buffer, $self->pattern_colors);
};

sub _find_colors_xs {
    my ($ptr, $pattern) = @_;
    _find_pixels($ptr, $pattern);
}

sub _find_colors_pp {
    my ($ptr, $pattern) = @_;
    my @uniq_pixels = uniq unpack('L*', $$ptr );
    my @matched_colors;
    for my $color (@$pattern) {
        if (any {$_ eq $color} @uniq_pixels) {
            #say "Found color: ", sprintf('%x', $color), " on step $s";
            push @matched_colors, $color;
        }
    }
    return \@matched_colors;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Iston::Analysis::Visibility

=head1 VERSION

version 0.08

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__
__C__
HV* _extract_pattern(SV* pixels_ref){
    HV* found_colors = newHV();
    SV* binary_string = SvRV(pixels_ref);
    STRLEN len;
    U32 *pixels_ptr;
    U32 i;

    pixels_ptr = (U32*) SvPV(binary_string, len);
    for (i = 0; i < len/4; i++) {
        bool has_value = hv_exists(found_colors, (const char*)pixels_ptr, sizeof(U32));
        if (!has_value) {
            U32 u_value = *pixels_ptr;
            SV* value = newSVuv(u_value);
            /* fprintf(stderr, "found pattern color: %X\n", u_value); */
            hv_store(found_colors, (const char*)pixels_ptr, sizeof(U32), value, 0);
        }
        pixels_ptr++;
    }
    return found_colors;
}

AV* _find_pixels(SV* pixels_ref, AV* pattern) {
    SV* binary_string = SvRV(pixels_ref);
    STRLEN len;
    U32 *pixels_ptr;
    pixels_ptr = (U32*) SvPV(binary_string, len);
    U32 i,j;

    SSize_t max_pattern_idx = av_top_index(pattern);
    if (max_pattern_idx <=0) {
        Perl_croak("Wrong pattern size");
    }

    U32* u_pattern = malloc(sizeof(U32)*(max_pattern_idx+1));
    U32* found_marks = malloc(sizeof(U32)*(max_pattern_idx+1));
    for (i = 0; i <= max_pattern_idx ; i++) {
        SV** value = av_fetch(pattern, i, 0);
        if (!value) {
            Perl_croak("Undefined values in pattern are not allowed");
        }
        u_pattern[i] = SvUV(*value);
        found_marks[i] = 0;
    }

    for (i = 0; i < len/4; i++) {
        U32 color = *pixels_ptr++;
        for (j = 0; j <= max_pattern_idx; j++ ) {
            if (u_pattern[j] == color) {
                found_marks[j] = 1;
            }
        }
    }
    AV* result = newAV();
    for (i = 0; i <= max_pattern_idx ; i++) {
        if (found_marks[i]) {
            SV* value = newSVuv(u_pattern[i]);
            av_push(result, value);
        }
    }
    free(u_pattern);
    free(found_marks);

    return result;
}
