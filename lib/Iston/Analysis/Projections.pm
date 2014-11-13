package Iston::Analysis::Projections;
# Abstract: The projections from ObservationPath points to the HTM's triangles
$Iston::Analysis::Projections::VERSION = '0.09';
use 5.12.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/maybe_zero/;
use List::Util qw/min max reduce/;
use Moo;

use aliased qw/Iston::Vector/;

has 'observation_path' => (is => 'ro', required => 1);
has 'htm'              => (is => 'ro', required => 1);

has 'projections_map'  => (is => 'lazy');

method _build_projections_map {
    my $max_level = max keys %{ $self->htm->levels_cache };
    my $sphere_vertices = $self->observation_path->vertices;
    my %examined_triangles_at;
    for my $vertex_index  ( 0 .. @$sphere_vertices - 1  ) {
        $examined_triangles_at{0}{$vertex_index} = $self->htm->levels_cache->{0};
    }
    my %projections_for;
    for my $level (0 .. $max_level) {
        for my $vertex_index  ( 0 .. @$sphere_vertices - 1  ) {
            my $examined_triangles = $examined_triangles_at{$level}->{$vertex_index};
            my $vertex_on_sphere = $sphere_vertices->[$vertex_index];
            my @vertices =
                map {
                    my $vertex = $_;
                    if (defined $vertex) {
                        $vertex =
                            Vector->new($_)->length <= 1
                            ? $_
                            : undef;
                    }
                    $vertex;
                }
                map {
                    my $intersection = $_->intersects_with($vertex_on_sphere);
                    $intersection;
                } @$examined_triangles;
            my @distances =
                map {
                    defined $_
                        ? $_->vector_to($vertex_on_sphere)->length
                        : undef;
                } @vertices;
            @distances =  map { maybe_zero($_) } @distances;
            my $min_distance = min grep { defined($_) } @distances;
            @vertices = map {
                (defined($vertices[$_]) && $distances[$_] == $min_distance)
                    ? $vertices[$_]
                    : undef;
            } (0 .. @vertices - 1);
            my @triangle_indices =
                grep { defined $vertices[$_] }
                (0 .. @vertices-1);
            my @paths =
                map  { $examined_triangles->[$_]->path }
                @triangle_indices;
            $projections_for{$vertex_index}->{$level} = \@paths;
            if ($level < $max_level) {
                $examined_triangles_at{$level+1}->{$vertex_index} = [
                    map {
                        @{ $examined_triangles->[$_]->subtriangles }
                    } @triangle_indices
                ];
            }
        }
    }
    return \%projections_for;
};

method walk ($action) {
    my $max_level = max keys %{ $self->htm->levels_cache };
    my $map = $self->projections_map;
    while (my ($vertex_index, $levels_path) = each %$map) {
        while (my ($level, $triangle_paths) = each %$levels_path) {
            for my $path (@$triangle_paths) {
                $action->($vertex_index, $level, $path);
            }
        }
    }
}

method distribute_observation_timings {
    my $records = $self->observation_path->history->records;
    my $last_index = @$records-1;
    $self->walk( sub {
        my ($vertex_index, $level, $path) = @_;
        if ($vertex_index < $last_index) {
            my $interval = reduce {$b - $a}
                map { $records->[$_]->timestamp }
                ($vertex_index, $vertex_index + 1);
            my $triangles = $self->projections_map->{$vertex_index}->{$level};
            my $time_share = $interval / @$triangles;
            $path->apply( sub {
                my ($triangle) = @_;
                my $payload = $triangle->payload;
                $payload->{total_time} //= 0;
                $payload->{total_time} += $time_share;
            });
        }
    });
};

method dump_analisys ($output_fh) {
    my $info = [];
    $self->walk( sub {
        my ($vertex_index, $level, $path) = @_;
        $path->apply(sub {
            my ($triangle) = @_;
            my $total_time = $triangle->payload->{total_time};
            $info->[$level]->{$path} = $total_time;
        });
    });

    say $output_fh "total time per level and per triangle path in seconds";
    for my $level (0 .. @$info - 1) {
        say $output_fh "==================";
        say $output_fh "level: $level";
        say $output_fh "==================\n";
        my @paths = sort { $a cmp $b } keys %{ $info->[$level] };
        for my $path (@paths) {
            say $output_fh "$path = ", $info->[$level]->{$path};
        }
        say $output_fh "\n";
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Analysis::Projections

=head1 VERSION

version 0.09

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
