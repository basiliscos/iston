#!/usr/bin/env perl

use 5.16.0;

use Data::Dumper::Concise;
use ExtUtils::Installed;
use FindBin;
use Getopt::Long qw(GetOptions :config no_auto_abbrev no_ignore_case);
use Module::ScanDeps qw/add_deps scan_deps/;
use Path::Tiny;

GetOptions(
    'o|output_dir=s' => \my $output_dir,
    'h|help'         => \my $help,
);


my $show_help = $help || !defined($output_dir);
die <<"EOF" if($show_help);
usage: $0 OPTIONS

$0 [options]

These options are available:
-o, --output_dir     Defines directory with output iston binary
-h, --help           Show this message.
EOF

my $executable = path(path($0)->parent, $^O eq 'MSWin32' ? 'iston.exe' : 'iston');
die "Cannot find executable $executable"
    unless -e $executable;

my $bin_dir = path(path($0)->parent->parent, 'bin');

my $rv_ref = scan_deps(
    files   => ["$bin_dir/iston.pl"],
    recurse => 1,
    compile => 1,
);
$rv_ref = add_deps( rv => $rv_ref, modules => [
	'Digest/MD5.pm',
]);
my @modules = sort {$a cmp $b} keys %$rv_ref;
say Dumper(\@modules);
#say Dumper($rv_ref);

my ($installation) = ExtUtils::Installed->new( skip_cwd => 1 );
my %module_for = map { $_ => 1 } $installation->modules;
my $base = path($output_dir);
$base->remove_tree if -e $base;

my $lib  = path($base, 'lib');
$lib->mkpath;

while ( my ($key, $data) = each %$rv_ref) {
	my $type = $data->{type};
	my $just_copy = sub {
		my $dst = path($lib, $data->{key});
		return if -e $dst;
		my $src = path($data->{file});
		$dst->parent->mkpath;
		$src->copy($dst);
	};
	if ($type ne 'module') {
		$just_copy->();
	} else {
		my $name = $key =~ s/\//::/gr;
		$name =~ s/\.pm$//;
		if (exists $module_for{$name} ) {
			say "module: $name";
			my @all_files = $installation->files($name);
            my ($main_file) = grep { /\Q$key\E$/ } @all_files;
            die "Cannot find main file for $key ($name)"
                unless $main_file;
            my $module_base = $main_file =~ s/$key//r;
			#say Dumper(\@all_files);
			#say Dumper($data);
			for my $file (@all_files ) {
				if ($file !~ /\blib\b/ || $file =~ /\.((pod)|(a)|(h))$/) {
					say "skip: $file";
					next;
				}
				my $rel_path = $file =~ s/\Q$module_base\E//r;
				my $new_path = path($lib, $rel_path);
				say "$file ($rel_path) -> $new_path";
				$new_path->parent->mkpath;
				next if -e $new_path;
				path($file)->copy($new_path);
			}
			#die("zzz");
		} else {
			$just_copy->();
		}
	}
}

$executable->copy($output_dir);
say "Copying complete";

