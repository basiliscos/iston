use 5.12.0;

use Test::More;
use Test::Warnings;

use Path::Tiny;

use aliased qw/Iston::History/;
use aliased qw/Iston::History::Record/;

subtest "simple-history" => sub {
    my $tmp_dir = Path::Tiny->tempdir( CLEANUP => 1);
    my $history_path = path($tmp_dir, "h.csv");
    my $h = History->new(path => $history_path);
    my $record = Record->new(
        timestamp => 0,
        alpha     => 1,
        beta      => 2,
        camera_x  => 3,
        camera_y  => 4,
        camera_z  => 5,
    );
    push @{ $h->records }, $record;
    $h->save;
    my $h2 = History->new(path => $history_path)->load;
    is_deeply($h->records, $h2->records);
};

done_testing;
