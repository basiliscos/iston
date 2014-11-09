#!/usr/bin/env perl

use 5.16.0;

use Benchmark qw(:all) ;
use Iston::Analysis::Visibility;
use SDL::Image;

my $sample = SDL::Image::load('t/data/2-colors.png');
my $ptr = $sample->get_pixels_ptr;

cmpthese(15, {
    'pure perl pattern extracting' => sub {
        Iston::Analysis::Visibility::_extract_pattern_pp($ptr);
    },
    'xs pattern extracting' => sub {
        Iston::Analysis::Visibility::_extract_pattern_xs($ptr);
    },
});

my $pattern = Iston::Analysis::Visibility::_extract_pattern_xs($ptr);
cmpthese(15, {
    'pure perl pattern matching' => sub {
        Iston::Analysis::Visibility::_find_colors_pp($ptr, $pattern);
    },
    'xs pattern matching' => sub {
        Iston::Analysis::Visibility::_find_colors_xs($ptr, $pattern);
    },
});
