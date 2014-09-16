package Iston::Drawable;

use 5.12.0;

use Moo::Role;

has rotation     => (is => 'rw', default => sub { [0, 0, 0] }, trigger => 1);
has enabled      => (is => 'rw', default => sub { 1 });
has display_list => (is => 'ro', default => sub { 0 });

sub rotate {
    my ($self, $axis, $value) = @_;
    if (defined $value) {
        $self->rotation->[$axis] = $value;
        $self->_trigger_rotation($self->rotation);
    }
    else {
        return $self->rotation->[$axis];
    }
}

requires qw/draw_function/;

1;
