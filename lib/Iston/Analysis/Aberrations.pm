package Iston::Analysis::Aberrations;
# Abstract: Tracks the (angle) direction changes of the observation path
$Iston::Analysis::Aberrations::VERSION = '0.04';
use 5.12.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use List::MoreUtils qw/pairwise/;
use Math::MatrixReal;
use Math::Trig;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'projections'    => (is => 'ro', required => 1);
has 'sphere_vectors' => (is => 'lazy');
has 'values'         => (is => 'lazy');

method _build_sphere_vectors {
    my $observation_path = $self->projections->observation_path;
    my $vertices = $observation_path->vertices;
    my $indices = $observation_path->sphere_vertex_indices;
    my $center = Vertex->new([0, 0, 0]);
    my @vectors = map {
        my @uniq_indices = @{$indices}[$_, $_+1];
        my ($a, $b) = map { $vertices->[$_] } @uniq_indices;
        my $v = $a->vector_to($b);
        my $great_arc_normal = $v * $center->vector_to($a);
        $v->payload->{starting_vertex } = $a;
        $v->payload->{great_arc_normal} = $great_arc_normal;
        $v;
    } (0 .. @$indices - 2);
    return \@vectors;
};

method _build_values {
    my $observation_path = $self->projections->observation_path;
    my $sphere_vectors = $self->sphere_vectors;
    my @normal_degrees = map {
        my ($v1, $v2) = map { $sphere_vectors->[$_] } $_, $_+1;
        my ($n1, $n2) = map { $_->payload->{great_arc_normal} } $v1, $v2;
        $n1->angle_with($n2);
    } (0 .. @$sphere_vectors - 2);
    return \@normal_degrees;
}

method dump_analisys ($output_fh) {
    my $observation_path = $self->projections->observation_path;
    my $vertices = $observation_path->vertices;
    my $v2s = $observation_path->vertex_to_sphere_index;
    my $values = $self->values;
    say $output_fh "vertex_index, aberration";
    for my $idx (0 .. @$vertices -1) {
        my $sphere_index = $v2s->[$idx];
        my $vector_index = $sphere_index - 1;
        my $value_index  = $vector_index - 1;
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

Iston::Analysis::Aberrations

=head1 VERSION

version 0.04

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
