#!/usr/bin/perl
use strict;

#my @output = `ps -A | grep plack`;
#killall( @output );

#my @output = `ps -A | grep starman`;

my @output = `ps -u \$USER | grep starman`;

killall( @output );

###########################################

sub killall {
    for my $line ( @_ ) {
        chomp $line;

        if ( $line =~ /^\s*(\d+).*master/ ) {
            print "+ $line : $1\n";
            system "kill -3 $1";
        }
    }
}