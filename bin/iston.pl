#!/usr/bin/env perl

use 5.12.0;

use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use OpenGL qw(:all);
use Path::Tiny;

use aliased qw/Iston::Application::Analyzer/;
use aliased qw/Iston::Application::Observer/;
use aliased qw/Iston::History/;

GetOptions(
    'o|object=s'         => \my $object_path,
    'n|no_history'       => \my $no_history,
    'N|no_full_screen'   => \my $no_fullscreen,
    'r|replay_history'   => \my $replay_history,
    'm|models_path=s'    => \my $models_path,
    'h|help'             => \my $help,
);

my $show_help = $help || (!$object_path && !$replay_history)
    || ($replay_history && !defined($models_path));
die <<"EOF" if($show_help);
usage: $0 OPTIONS

     $0 [options]

These options are available:
  -o, --object         Generates pair of private an public keys and stores them
                       in the current directory
  -n, --no_history     Do not record history
  -N, --no_full_screen Do not enter into fullscreen mode
  -m, --models_path    Path to directory with models
  -r  --replay_history Replay history mode
  -h, --help           Show this message.
EOF

my $app;

if($replay_history) {
    $app = Analyzer->new(
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

my $t; $t = AE::timer 0, 0.05, sub {
    $app->refresh_world;
};
$app->cv_finish->recv;
say "bye-bye";

# kill self to avoid problem with pure virtual method called
#kill 9, $$;
