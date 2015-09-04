#!/usr/bin/env perl
use 5.10.0;
use common::sense;
use utf8;
use Term::ANSIColor qw(:constants);
use Pinakoteka::CLI;

use BD::Update::Table;
use BD::Update::Schema;

$|++;

# TODO: вывести параметрами
my $shema = BD::Update::Schema::init(
    real => 1,
    show => 1,
);

say RESET;

my $pwd = $dir . '/bin/db_update/scripts';

opendir(my $dh, $pwd) || die "can't opendir $pwd: $!";
my @files = sort grep { /\.pl$/ && -f "$pwd/$_" } readdir($dh);
closedir $dh;

my %patches = %{ $dbh->selectall_hashref(qq{SELECT `data` FROM patches}, 'data' ) };

my $sth = $dbh->prepare(qq{INSERT INTO patches (data) VALUES (?)});

for my $file ( @files ) {
    say BLUE "----\n", RESET, BOLD BLUE "File:", RESET, BOLD " $file", RESET;

    if ( exists $patches{$file} ) {
        say BOLD GREEN '  already applied, skipping...', RESET;
        next;
    }

    open( my $in, '<', "$pwd/$file") or die $!;
    my $string = do { local $/; <$in> };
    close $in;

    eval($string);

    if ( $@ ) {
        say RED "ERROR: $@", RESET;
    }
    else {
        say GREEN "Applied", RESET;
        $sth->execute($file);
    }
}
