#!/usr/bin/env perl

use 5.16.0;

use Data::Dumper::Concise;
use FindBin;
use Module::ScanDeps;
use Path::Tiny;

my $bin_dir = path($0)->parent;

my $rv_ref = scan_deps(
    files   => ["$bin_dir/iston.pl"],
    recurse => 1,
    compile => 1,
);
my @modules = sort {$a cmp $b} keys %$rv_ref;
#say Dumper(\@modules);
say Dumper($rv_ref);
