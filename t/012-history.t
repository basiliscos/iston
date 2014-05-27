use 5.12.0;

use Test::More;
use Test::Warnings;

use Path::Tiny;

use aliased qw/Iston::History/;

subtest "simple-history" => sub {
    my $tmp_dir = Path::Tiny->tempdir( CLEANUP => 1);
    my $history_path = path($tmp_dir, "h.csv");
    my $h = History->new(path => $history_path);
    my $data = [0, 0, 0, 0, 0, 0];
    push @{ $h->records }, $data;
    $h->save;
    my $h2 = History->new(path => $history_path)->load;
    is_deeply($h->records, $h2->records);
};

done_testing;
