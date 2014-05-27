package Iston::History;

use 5.12.0;

use Function::Parameters qw(:strict);
use Moo;
use Path::Tiny qw//;
use Text::CSV;

has path => (is => 'ro', required => 1);
has records => (is => 'rw', default => sub{ [] } );

method load {
    my $csv = Text::CSV->new({
        binary   => 1,
        sep_char => ',',
    }) or die "Cannot use CSV: " . Text::CSV->error_diag;
    my $path = $self->path;
    open my $fh, "<:encoding(utf8)", $path or die "$path: $!";
    my @rows;
    my $header = $csv->getline( $fh ); # just remove it from headers
    while ( my $row = $csv->getline( $fh ) ) {
        push @rows, $row;
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    $self->records(\@rows);
    $self;
};

method save {
    my $header = join(',', qw/timestamp a b camera_x camera_y camera_z/);
    my @data = map { $_ . "\n"}
        ($header,  map { join(',', @$_ ) } @{ $self->records } );
    Path::Tiny->new($self->path)->spew(@data);
};

method log_state($record) {
    push @{ $self->records }, [@$record];
}

method elements {
    scalar(@{ $self->records });
}

1;
