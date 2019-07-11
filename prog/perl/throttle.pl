#!/usr/bin/perl
use strict;
use bignum;
use Getopt::Long;

my $ratelim = 1/0; # "use bignum" makes division-by-zero result Inf

sub getopts {
    GetOptions ("rate-limit=s" => \$ratelim)
        or die("Error in command line arguments\n");
}

my $bufsz = 8;
my @SAVE_ARGV = @ARGV;
getopts;
@ARGV = @SAVE_ARGV;

{
binmode STDIN;
binmode STDOUT;
local $| = 1; # auto flush
local $/ = \$bufsz;

my $totalb = 0;
my $tm_start = time();
my $tm_now;
my $elapsed;
my $bps;

# read() blocks, but sysread() returns as soon as some bytes available
while (sysread(STDIN,$_,$bufsz)) {
$totalb += length();
print();
while(1) {
$tm_now = time();
$elapsed = $tm_now - $tm_start;
$bps = $totalb / $elapsed; # "use bignum" makes division-by-zero result Inf
#print $bps . "\n";
last if ($bps <= $ratelim);
sleep(1);
}
}
}
