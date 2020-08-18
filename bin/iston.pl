#!/usr/bin/env perl

use 5.20.0;

use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use OpenGL qw(:all);
use Path::Tiny;

use aliased qw/Iston::Application::Analyzer/;
use aliased qw/Iston::Application::HTMViewer/;
use aliased qw/Iston::Application::Observer/;
use aliased qw/Iston::Application::Marker/;
use aliased qw/Iston::Application::Player/;
use aliased qw/Iston::History/;

GetOptions(
    'o|object=s'         => \my $object_path,
    'n|no_history'       => \my $no_history,
    's|screen_mode=i'    => \my $screen_mode,
    'M|marker_mode'      => \my $marker_mode,
    'T|htm_mode'         => \my $htm_mode,
    'r|replay_history'   => \my $replay_history,
    'p|history_player'   => \my $history_player,
    'm|models_path=s'    => \my $models_path,
    'H|history_path=s'   => \my $history_path,
    'h|help'             => \my $help,
);

my $show_help = $help || (!$object_path && (!$replay_history && !$marker_mode && !$htm_mode))
    || ($replay_history && !defined($models_path))
    || ($history_player && !defined($history_path))
    || ($screen_mode    && (($screen_mode < 1) ||($screen_mode > 3)))
    ;

die <<"EOF" if($show_help);
usage: $0 OPTIONS

     $0 [options]

These options are available:
  -o, --object         Generates pair of private an public keys and stores them
                       in the current directory
  -n, --no_history     Do not record history
  -s, --screen_mode    Screen mode to render (1 = fullscreen, 2 = halfscreen, 3 = default)
  -M, --marker_mode    Marker mode
  -T, --htm_mode       HTM mode
  -m, --models_path    Path to directory with models
  -r  --replay_history Replay history mode
  -p, --history_player Dedicated app to play history and exit
  -H, --history_path   Full path to history file
  -h, --help           Show this message.
EOF

$screen_mode //= Iston::SCREEN_DEFAULT;
my $app;

if (-e "iston.config") {
    say "loading iston.config";
    my $data =  path("iston.config")->slurp;
    my $config = eval "$data";
    if ($@ || ref($config) ne 'HASH') {
        say "failed loading config...";
    } else {
        for my $k (keys %$config) {
            $ENV{$k} = $config->{$k};
        }
    }
}

if ($replay_history) {
    $app = Analyzer->new(
        models_path => $models_path // '.',
        screen_mode => $screen_mode,
    );
} elsif ($marker_mode) {
    $app = Marker->new(
        models_path => $models_path // '.',
        screen_mode => $screen_mode,
    );
} elsif ($htm_mode) {
    $app = HTMViewer->new(
        models_path => $models_path // '.',
        screen_mode => $screen_mode,
    );
} elsif ($history_player) {
    $app = Player->new(
        object_path  => $object_path,
        history_path => $history_path,
        screen_mode => $screen_mode,
    );
    $app->start_replay;
} else {
    $object_path = path($object_path);
    my $history = !$no_history
        ? History->new(path => join('_', 'history', time, $object_path->basename ) . ".csv")
        : undef;
    $app = Observer->new(
        object_path => $object_path,
        history     => $history,
        screen_mode => $screen_mode,
    );
}

$app->sdl_app->run;
