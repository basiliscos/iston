#!/usr/bin/env perl

use 5.12.0;

use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use OpenGL qw(:all);
use Path::Tiny;

use aliased qw/Iston::Application::Analyzer/;
use aliased qw/Iston::Application::Observer/;
use aliased qw/Iston::Application::Marker/;
use aliased qw/Iston::History/;

GetOptions(
    'o|object=s'         => \my $object_path,
    'n|no_history'       => \my $no_history,
    'N|no_full_screen'   => \my $no_fullscreen,
    'M|marker_mode'      => \my $marker_mode,
    'r|replay_history'   => \my $replay_history,
    'm|models_path=s'    => \my $models_path,
    'h|help'             => \my $help,
);

my $show_help = $help || (!$object_path && !$replay_history && !$marker_mode)
    || ($replay_history && !defined($models_path));
die <<"EOF" if($show_help);
usage: $0 OPTIONS

     $0 [options]

These options are available:
  -o, --object         Generates pair of private an public keys and stores them
                       in the current directory
  -n, --no_history     Do not record history
  -N, --no_full_screen Do not enter into fullscreen mode
  -M, --marker_mode    Marker mode
  -m, --models_path    Path to directory with models
  -r  --replay_history Replay history mode
  -h, --help           Show this message.
EOF

my $app;

if ($replay_history) {
    $app = Analyzer->new(
        models_path => $models_path // '.',
        full_screen => !$no_fullscreen,
    );
} elsif ($marker_mode) {
    $app = Marker->new(
        models_path => $models_path // '.',
        full_screen => !$no_fullscreen,
    );
} else {
    $object_path = path($object_path);
    my $history = !$no_history
        ? History->new(path => join('_', 'history', time, $object_path->basename ) . ".csv")
        : undef;
    $app = Observer->new(
        object_path => $object_path,
        history     => $history,
        full_screen => !$no_fullscreen,
    );
}

$app->sdl_app->run;
