use 5.16.0;

use Test::More;
use Test::Warnings;

use Path::Tiny;
use SDL::Image;
use SDL::Surface;
use SDLx::Surface;

use aliased qw/Iston::Analysis::Visibility/;

subtest 'simple cases' => sub {
    my $pattern = SDL::Image::load('t/data/2-colors.png');
    my $v = Visibility->new( pattern => $pattern);
    my $pattern_colors = $v->pattern_colors;
    is scalar(@$pattern_colors), 2;
    is_deeply [sort {$a <=> $b} @$pattern_colors],
        [0x00FFFFFF, 0xFF00FF00]; # transparent + green

    subtest "test visibility on pattern itself" => sub {
        my $matched_colors = $v->find($pattern);
        is_deeply $pattern_colors, $matched_colors;
    };

    subtest "simple matches" => sub {
        my $image = SDL::Surface->new(
            SDL_SWSURFACE, 2, 2, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000,
        );
        my $matrix = SDLx::Surface->new( surface => $image);
        is_deeply $v->find($image), [], "nothing found on new/black image";

        $matrix->[0][0] = 0xFFFF0000; # red
        is_deeply $v->find($image), [], "nothing found on black image with red pixel";
        $matrix->[1][1] = 0xFF00FF00; # green
        is_deeply $v->find($image), [0xFF00FF00], "green pixel on artificial image";
    };

};

done_testing;
