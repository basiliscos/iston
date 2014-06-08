package Iston::Drawable;

use 5.12.0;

use Moo::Role;

has rotation => (is => 'rw', default => sub { [0, 0, 0] });
has enabled => (is => 'rw', default => sub { 1 });

sub rotate {
    my ($self, $axis, $value) = @_;
    if (defined $value) {
        $self->rotation->[$axis] = $value;
    }
    else {
        return $self->rotation->[$axis];
    }
}

requires qw/draw/;

1;
