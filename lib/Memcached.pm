package Memcached;
use common::sense;
use Cache::Memcached::Fast;
use Encode qw(_utf8_on);

my $memc;

sub connect_memcached {
    $memc = Cache::Memcached::Fast->new(
        {
            'servers' => ['localhost:11211'],
            utf8 => 1,
        },
    );

    BD::memcached($memc);
}

*new = \&connect_memcached;

sub get {
    shift;
    my $t = $memc->get(@_);
    return $t;
}

sub set {
    shift;
    $memc->set(@_);
}

sub delete {
    shift;
    $memc->delete(@_);
}

1;