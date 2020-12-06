package Iston::Plugin::MarkersDistance;

use strict;
use warnings;
use JSON::XS;
use Math::Trig;
use Moo;
use Path::Tiny;
use SDL::Events;

has app               => (is => 'ro', required => 1);
has markers_file      => (is => 'ro', required => 1);
has markers_container => (is => 'rw', required => 0);
has distances         => (is => 'ro', default  => sub { [] });

use aliased qw/Iston::Object::MarkerContainer/;
use aliased qw/Iston::Zone/;

sub BUILD(@) {
    my $self = shift;
    print "Instantiating ", __PACKAGE__, "\n";
    my $app = $self->app;
    my $mc = MarkerContainer->new(
        current_point => sub { $app->current_vertex },
        shader        => $app->shader_for->{object},
        notifyer      => $app->_notifyer,
    );
    push @{ $app->objects }, $mc;
    $mc->enabled(0);
    $app->_notifyer->subscribe('zone_distances_change' => sub {
       my (undef, $dists) = @_;
       push @{ $self->distances }, $dists;
    });

    my $marker_path  = path($self->markers_file);
    my $markers_data = decode_json($marker_path->slurp_utf8);
    for (@{ $markers_data->{zones} } ) {
        push @{ $mc->zones }, Zone->new(
            xz     => $_->{xz},
            yz     => $_->{yz},
            spread => $_->{spread},
            active => 0,
        );
    }
    $mc->name($markers_data->{name});
    my $scale_to = $app->main_object->scale * $app->main_object->radius;
    $mc->scale($scale_to);
    $mc->clear_draw_function;
    $self->markers_container($mc);
}

sub _toggle_markers {
    my $self = shift;
    my $value = $self->markers_container->enabled;
    $value = !$value;
    $self->markers_container->enabled($value);
}

sub postprocess_event { }

sub process_event {
    my ($self, $event) = @_;
    my $action;
    if ($event->type == SDL_KEYUP) {
        my $dispatch_table = {
            SDLK_m,     '_toggle_markers',
        };
        my $key_sym = $event->key_sym;
        my $command = $dispatch_table->{$key_sym};
        $action = sub { $self->$command }  if defined $command;
    }
    return $action;
}

sub on_exit {
    my ($self, $analisys_dir) = @_;
    my @lines = map {
        join(", ", map { sprintf("%0.2f", rad2deg $_)  } @$_);
    } @{ $self->distances };
    my $header = join(", ", map { 'm_' . $_ } (1 .. @{ $self->distances->[0] }));
    my @data = map { $_ . "\n"} ($header, @lines);
    Path::Tiny->new("$analisys_dir/marker-distances.csv")->spew(@data);
}

1;

