package Iston::EventDistributor;
$Iston::EventDistributor::VERSION = '0.10';
use 5.16.0;

use Carp;
use Function::Parameters qw(:strict);
use List::MoreUtils qw/any/;
use Moo;

has _signals     => (is => 'ro', default => sub { [] });
has _subscribers => (is => 'ro', default => sub { {} });
has _last_values => (is => 'ro', default => sub { {} });

method declare($signal_name) {
    croak("Signal $signal_name has been already declared")
        if(any { $_ eq $signal_name } @{ $self->_signals } );
    push @{ $self->_signals }, $signal_name;
};

method subscribe($signal_name, $callback) {
    croak "$signal_name hasn't been declared"
        unless(any { $_ eq $signal_name } @{ $self->_signals });
    croak "callback must be a code reference"
        unless ref($callback) eq 'CODE';
    push @{ $self->_subscribers->{$signal_name} }, $callback;
};

method publish($signal_name, $value) {
    croak "$signal_name hasn't been declared"
        unless(any { $_ eq $signal_name } @{ $self->_signals });
    $self->_last_values->{$signal_name} = $value;
    return unless exists $self->_subscribers->{$signal_name};
    for my $cb (@{ $self->_subscribers->{$signal_name} }) {
        $cb->($signal_name, $value);
    }
};

method last_value($signal_name) {
    croak "$signal_name hasn't been declared"
        unless(any { $_ eq $signal_name } @{ $self->_signals });
    return $self->_last_values->{$signal_name};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Iston::EventDistributor

=head1 VERSION

version 0.10

=head1 AUTHOR

Ivan Baidakou <dmol@gmx.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ivan Baidakou.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
