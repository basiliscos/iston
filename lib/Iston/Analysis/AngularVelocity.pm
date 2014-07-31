package Iston::Analysis::AngularVelocity;
# Abstract: Tracks the value of angular velocity.
$Iston::Analysis::AngularVelocity::VERSION = '0.04';
use 5.12.0;

use Function::Parameters qw(:strict);
use List::Util qw/reduce/;
use Math::Trig;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'observation_path' => (is => 'ro', required => 1);
has 'sphere_vectors'   => (is => 'ro', required => 1);
has 'values'           => (is => 'lazy');

method _build_values {
    my $observation_path = $self->observation_path;
    my $vectors = $self->sphere_vectors->vectors;
    my @angles = map {
        my $v = $_;
        my ($a, $b) =
            map { Vector->new($_) }
            map { $v->payload->{$_} }
            qw/start_vertex end_vertex/;
        my $angle = $a->angle_with($b);
        $angle;
    } @$vectors;
    my @velocities = map {
        my $idx = $_;
        my $angle = $angles[$idx];
        my ($t1, $t2) =
            map { $observation_path->history->records->[$_]->timestamp }
            ($idx, $idx+1);
        my $diff = $t2-$t1;
        my $v = $diff? $angle/$diff : 0;
    } (0 .. @angles-1);
    return \@velocities;
}

method dump_analisys ($output_fh) {
    my $observation_path = $self->observation_path;
    my $vertices = $observation_path->vertices;
    my $v2s = $observation_path->vertex_to_sphere_index;
    my $values = $self->values;
    say $output_fh "vertex_index, velocity(degree/sec)";
    for my $idx (0 .. @$vertices -1) {
        my $sphere_index = $v2s->[$idx];
        my $value_index  = $sphere_index-1;
        my $value = 0;
        if ($value_index >= 0 && $v2s->[$idx-1] != $sphere_index) {
            $value = $values->[$value_index];
        }
        $value = sprintf('%0.2f', rad2deg($value));
        say $output_fh "$idx, $value";
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Analysis::AngularVelocity

=head1 VERSION

version 0.04

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
