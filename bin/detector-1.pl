#!/usr/bin/env perl

use 5.18.0;
use warnings;
use strict;

use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use JSON::XS;
use Path::Tiny;
use Math::Trig;

use aliased qw/Iston::EventDistributor/;
use aliased qw/Iston::History/;
use aliased qw/Iston::Zone/;
use aliased qw/Iston::Analysis::Aberrations/;
use aliased qw/Iston::Analysis::AngularVelocity/;
use aliased qw/Iston::Object::ObservationPath/;
use aliased qw/Iston::Object::SphereVectors::VectorizedVertices/;
use aliased qw/Iston::Object::SphereVectors::GeneralizedVectors/;
use aliased qw/Iston::Object::MarkerContainer/;

GetOptions(
    's|settings=s'       => \my $settings_path,
    'H|history_path=s'   => \my $history_path,
    'm|markers_path=s'   => \my $markers_path,
    'h|help'             => \my $help,
);

my $show_help = $help || !$settings_path || !$history_path || !$markers_path;

die <<"EOF" if($show_help);
usage: $0 OPTIONS

     $0 [options]

These options are available:
  -s, --settings       Path to settings file
  -H, --history_path   Full path to history file
  -m, --markers_path   Full path to markers file
  -h, --help           Show this message.
EOF

say "loading settings...";
my $settings =  eval path($settings_path)->slurp;
if ($@ || ref($settings) ne 'HASH') {
    say "failed loading settings...";
}

say "loading markers...";
my $notifier = EventDistributor->new;
$notifier->declare('view_change');
my $mc = MarkerContainer->new(notifyer => $notifier);
my $markers_data = decode_json(path($markers_path)->slurp_utf8);
for (@{ $markers_data->{zones} } ) {
    push @{ $mc->zones }, Zone->new(
        xz     => $_->{xz},
        yz     => $_->{yz},
        spread => $_->{spread},
        active => 0,
    );
}
$mc->name($markers_data->{name});

say "loading history...";
my $history = History->new( path => $history_path )->load;

say "calculating observation path...";
my $observation_path = ObservationPath->new(history => $history);
my $sphere_vectors = VectorizedVertices->new(
    vertices       => $observation_path->vertices,
    vertex_indices => $observation_path->sphere_vertex_indices,
    default_color  => [1.0, 0.0, 0.0, 0.0],
);

say "calculating abberations...";
my $aberrations = Aberrations->new(sphere_vectors => $sphere_vectors);
$aberrations->values;

say "calculating angular velocity...";
my $angular_velocity = AngularVelocity->new(
    observation_path => $observation_path,
    sphere_vectors   => $sphere_vectors,
);
$angular_velocity->values;

my $generalization_distance = $settings->{'generalization.distance'};
say "linearizing... (d = $generalization_distance)";
my $generalized_vectors = GeneralizedVectors->new(
    distance       => deg2rad($generalization_distance),
    source_vectors => $sphere_vectors,
    default_color  => [0.0, 0.0, 0.75, 0.0]
);
$generalized_vectors->vectors;
say scalar( @{ $generalized_vectors->vectors } ), " linear paths has been detected";

for my $i (0 ..  @{ $generalized_vectors->vectors } - 1) {
    say "\nanalyzing vector #", ($i + 1);
    my $gv = $generalized_vectors->vectors->[$i];
    my ($sv, $ev) = map { $gv->payload->{$_} } qw/start_vertex end_vertex/;
    my ($si, $ei);
    for (my $j = 0; $j < @{ $observation_path->vertices }; ++$j) {
        my $v = $observation_path->vertices->[$j];
        $si = $j, next if ($v eq $sv);
        $ei = $j, last if ($v eq $ev);
    }
    my $vertices_count = $ei - $si;
    say "vertices count = ", $vertices_count, " (", $si, " .. ", $ei, ")";
    next if $vertices_count < $settings->{'generalization.min_vertices'};

    # calculate mean & variance
    my $mean = 0;
    for(my $j = $si; $j < $ei; $j++) {
        $mean += $angular_velocity->values->[$j];
    }
    $mean /= ($vertices_count - 1);

    my $var = 0;
    for(my $j = $si; $j < $ei; $j++) {
        my $x = ($mean - $angular_velocity->values->[$j]);
        $var += $x * $x;
    }
    $var /= ($vertices_count - 1);
    $var = sqrt($var);
    my @last_speeds = map { $angular_velocity->values->[$_] }  ($ei - 5 .. $ei - 1);
    say "mean velocity = ", sprintf("%0.4f", $mean), ", variance velocity = ", sprintf("%0.4f", $var);
    say "last velocities = ", join(", ", map { sprintf("%0.4f", $_) } @last_speeds );

    my $pt = $observation_path->vertices->[$ei];
    my $distances = $mc->calc_distances($pt);
    say "zone distances = ", join(", ", map { sprintf("%0.4f", $_) } @$distances );
    my ($best_zone, $min_dist) = (0, $distances->[0]);
    for (my $j = 1; $j < @$distances; ++$j) {
        if ($distances->[$j] < $min_dist) {
            ($best_zone, $min_dist) = ($j, $distances->[$j]);
        }
    }
    say "nearest zone: ", $best_zone + 1;
}


say "normal exit";