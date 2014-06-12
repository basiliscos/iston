package Iston::TrianglePath;
$Iston::TrianglePath::VERSION = '0.02';
use 5.12.0;

use overload
    '""' => '_stringify',
    fallback => 1,
    ;

sub new {
    my ($class, $parent, $index) = @_;
    if (!defined($index) || !ref($parent)) {
        $index = $parent;
        $parent = undef;
    }
    my $self = {
        _parent => $parent,
        _index  => $index
    };
    return bless $self => $class;
}

sub triangle {
    my ($self, $value) = @_;
    $self->{_triangle} = $value if $value;
    return $self->{_triangle};
}

sub apply {
    my ($self, $action) = @_;
    $action->($self->triangle);
}

sub _gather_full_path {
    my $self = shift;
    my @full_path = ($self->{_index});
    my $parent = $self->{_parent};
    while ($parent) {
        push @full_path, $parent->{_index};
        $parent = $parent->{_parent};
    }
    @full_path = reverse @full_path;
    return \@full_path;
}

sub _stringify {
    my $self = shift;
    my $full_path = $self->_gather_full_path;
    return sprintf('path[%s]', join(':', @$full_path));
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::TrianglePath

=head1 VERSION

version 0.02

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
