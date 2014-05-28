package Iston::History;

use 5.12.0;

use Function::Parameters qw(:strict);
use Moo;
use Path::Tiny qw//;
use Text::CSV;

use aliased qw/Iston::History::Record/;

has path => (is => 'rw', required => 0);
has records => (is => 'rw', default => sub{ [] } );

method load {
    my $path = $self->path;
    croak("Path should be specified") unless defined($path);

    my $csv = Text::CSV->new({
        binary   => 1,
        sep_char => ',',
    }) or die "Cannot use CSV: " . Text::CSV->error_diag;
    open my $fh, "<:encoding(utf8)", $path or die "$path: $!";
    my @rows;
    my $header = $csv->getline( $fh ); # just remove it from headers
    for (0 .. @$header - 1) {
        my $h = $header->[$_];
        die("unknown header: $h ")
            unless $h eq $Iston::History::Record::fields[$_];
    }
    while ( my $row = $csv->getline( $fh ) ) {
        my %data = map { $header->[$_] => $row->[$_] } (0 .. @$header - 1);
        push @rows, Record->new(%data);
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    $self->records(\@rows);
    $self;
};

method save {
    my $path = $self->path;
    croak("Path should be specified") unless defined($path);

    my @fields = @Iston::History::Record::fields;
    my $header = join(',', @fields);
    my @rows = map {
        my $r = $_;
        [map { $r->$_ } @fields];
    } @{ $self->records };
    my @data = map { $_ . "\n"}
        ($header,  map { join(',', @$_ ) } @rows );
    Path::Tiny->new($path)->spew(@data);
};

method log_state($record) {
    push @{ $self->records }, [@$record];
}

method elements {
    scalar(@{ $self->records });
}

1;
