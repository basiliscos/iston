package Iston::TrianglePath;

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

sub apply {
    my ($self, $root, $action) = @_;
    my $full_path = $self->_gather_full_path;
    my $list = $root;
    my $triangle;
    my $last_element = @$full_path - 1;
    for my $i (0 .. $last_element) {
        my $index = $full_path->[$i];
        $triangle = $list->[$index];
        $list = $triangle->subtriangles unless $i == $last_element;
    }
    return warn "Can't found triangle at path " . $self unless $triangle;
    $action->($triangle, $self);
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
