#!/usr/bin/env perl

use 5.16.0;

use Benchmark qw(:all) ;
use Iston::Analysis::Visibility;
use SDL::Image;

my $pattern = SDL::Image::load('t/data/2-colors.png');
my $ptr = $pattern->get_pixels_ptr;

cmpthese(5, {
    'pure perl pattern extracting' => sub {
        Iston::Analysis::Visibility::_extract_pattern_pp($ptr);
    },
    'xs pattern extracting' => sub {
        Iston::Analysis::Visibility::_extract_pattern_xs($ptr);
    },
});
