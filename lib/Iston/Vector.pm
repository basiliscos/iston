package Iston::Vector;
$Iston::Vector::VERSION = '0.10';
use 5.12.0;

use Carp;
use Function::Parameters qw(:strict);
use List::Util qw/reduce/;
use List::MoreUtils qw/pairwise/;
use Math::Trig qw/acos_real/;

use Moo;

use overload
    '+'   => '_add',
    '-'   => '_sub',
    '*'   => '_mul',
    '=='  => '_equal',
    '""'  => '_stringify',
    fallback => 1,
    ;

use parent qw/Exporter/;
our @EXPORT_OK = qw/normal/;

with('Iston::Payload');

#has 'values' => (is => 'ro', required => 1, isa => sub { croak("not array") unless ref($_[0]) eq 'ARRAY' });
has 'values' => (is => 'ro', required => 1, );
has 'rotation_angles' => (is => 'lazy');

fun normal($vertices, $indices) {
    croak "Normal vector is defined exactly by 3 vertices"
        unless @$indices == 3;
    my @vertices = map { $vertices->[$_] } @$indices;
    my $a = $vertices[0]->vector_to($vertices[1]);
    my $b = $vertices[0]->vector_to($vertices[2]);
    return ($a * $b)->normalize;
}

sub _mul_vector {
    my ($a, $b) = map { $_->values} @_;
    my @values = (
        $a->[1]*$b->[2] - $a->[2]*$b->[1],
        $a->[2]*$b->[0] - $a->[0]*$b->[2],
        $a->[0]*$b->[1] - $a->[1]*$b->[0],
    );
    return Iston::Vector->new(values =>\@values);
}

sub _mul_scalar {
    my ($a, $s) = @_;
    my @values = map { $_ * $s } @{ $a->values };
    return Iston::Vector->new(values => \@values);
}

# does either vector multiplicaiton or vector to scalar
sub _mul {
    my ($a, $b) = @_;
    if (ref($b) eq 'Iston::Vector') {
        return _mul_vector($a, $b);
    } else {
        return _mul_scalar($a, $b);
    }
};

sub scalar_multiplication {
    my ($p, $q) = map {$_->values } @_;
    return
        reduce   { $a + $b }
        pairwise { $a * $b }
        @$p, @$q
}

sub _add {
    my ($a, $b) = map {$_->values } @_[0,1];
    my @r = map { $a->[$_] + $b->[$_] } (0 .. 2);
    return Iston::Vector->new(values => \@r);
}

sub _sub {
    my ($a, $b) = map {$_->values } @_[0,1];
    my @r = map { $a->[$_] - $b->[$_] } (0 .. 2);
    return Iston::Vector->new(values => \@r);
}

sub _equal {
    my $r = 1;
    for (0 .. 2) {
        $r &= $a->[$_] == $b->[$_];
    }
    $r;
}

sub length {
    my $self = shift;
    my $values = $self->values;
    return sqrt(
        reduce  { $a + $b }
            map {$values->[$_]**2 }
            (0 .. 2)
    );
}

sub normalize {
    my $self = shift;
    my $length = $self->length;
    return $self if($length == 0);

    my $values = $self->values;
    my @r =map { $values->[$_] / $length } (0 .. 2);
    return Iston::Vector->new(values => \@r);
}

sub _stringify {
    my $values = shift->values;
    return sprintf('vector[%0.4f, %0.4f, %0.4f]', @$values);
}

sub smart_2string {
    my $values = shift->values;
    my @values =
        map { $_ eq '-0.0000' ? '0.0000' : $_ }
        map { sprintf('%0.4f', $_) } @$values;
    sprintf('vector[%s, %s, %s]', @values);
}

sub is_zero {
    my $self = shift;
    return $self->smart_2string eq 'vector[0.0000, 0.0000, 0.0000]';
}

sub angle_with {
    my ($a, $b) = @_;
    my $cos_a = $a->scalar_multiplication($b) / ($a->length * $b->length);
    # take care of accurracy to do not jump accidently
    # to complex plane
    # $cos_a = $cos_a > 1
    #     ? 1
    #     : $cos_a < -1
    #     ? -1
    #     : $cos_a;
    # return acos($cos_a);
    return acos_real($cos_a);
}

sub _build_rotation_angles {
    my $self = shift;
    my ($a, $b) = map { $self->payload->{$_} } qw/start_vertex end_vertex/;
    die("no start vertex payload") unless $a;
    die("no end vertex payload") unless $a;

    my ($rot_a, $rot_b) = map {
        $_->payload->{rotation} // die("No rotation payload for vertex")
    } ($a, $b);
    my @rot_diff = map {$rot_b->[$_] - $rot_a->[$_]} (0, 1);
    return \@rot_diff;
};

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::Vector

=head1 VERSION

version 0.10

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
