package Iston::Analysis::Aberrations;
# Abstract: Tracks the (angle) direction changes of the observation path
$Iston::Analysis::Aberrations::VERSION = '0.07';
use 5.12.0;

use Function::Parameters qw(:strict);
use Iston::Utils qw/rotation_matrix/;
use List::MoreUtils qw/pairwise/;
use List::Util qw/reduce/;
use Math::Trig;
use Moo;

use aliased qw/Iston::Vector/;
use aliased qw/Iston::Vertex/;

has 'sphere_vectors' => (is => 'ro', required => 1);
has 'values'         => (is => 'lazy');

method _build_values {
    my $sphere_vectors = $self->sphere_vectors->vectors;
    my @normal_degrees = map {
        my ($v1, $v2) = map { $sphere_vectors->[$_] } $_, $_+1;
        my ($n1, $n2) = map { $_->payload->{great_arc_normal} } $v1, $v2;
        my $angle = $n1->angle_with($n2);
        if ($angle) {
            my $sign =
                reduce {$a + $b}
                map {
                    my $idx = $_;
                    my ($c, $c0) =
                        map { $_->payload->{end_vertex}->[$idx] }
                        ($v2, $v1);
                    $n1->[$_]*($c-$c0);
                } (0 .. 2);
            $angle *= ($sign > 0) ? 1 : -1;
        }
        $angle;
    } (0 .. @$sphere_vectors - 2);
    return \@normal_degrees;
}

method dump_analisys ($output_fh, $observation_path) {
    my $vertices = $observation_path->vertices;
    my $v2s = $observation_path->vertex_to_sphere_index;
    my $values = $self->values;
    my $mapper = $self->sphere_vectors->vertex_to_vector_function;
    say $output_fh "vertex_index, aberration";
    for my $idx (0 .. @$vertices -1) {
        my $sphere_index = $v2s->[$idx];
        my $vector_index = $mapper->($idx) // 0; # $sphere_index - 1;
        my $value_index  = $vector_index - 1;
        my $value = 0;
        if ($vector_index > 0 && $v2s->[$idx-1] != $sphere_index) {
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

version 0.07

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
