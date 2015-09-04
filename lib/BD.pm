package BD;
use strict;
use warnings;
use DBI;
use Mojo::Home;
use Mojo::Log;
use Data::Dumper;
use DDP;

my $db;

my $print_errors = 1;

# params: cluster
# arg-descr:
# cluster - имя кластера, например main или unity, как оно записано в конфиге в разделе db

sub get_master {
    my $self = shift;
    return $self->get_db( 'master', @_ );
}

sub get_slave {
    my $self = shift;
    return $self->get_db( 'slave', @_ );
}

*get_global_slave  = \&get_slave;
*get_global_master = \&get_master;

sub get_db {
    my( $self, $sub, $cluster ) = @_;
    $cluster = 'main' unless $cluster;
#    $self->connect_all($Fantlab::mojo->config) unless $db->{$cluster}->{connected};
    my $key = get_key($cluster, $sub);
    return $db->{$key}->[int(rand(scalar @{$db->{$key}}))];
}

sub connect_all {
    my( $class, $config ) = @_;

    if ( $ARGV[0] && $ARGV[0] eq 'test' ) {
        $config->{db} = {
            main => {
                master => {
                    1 => {},
                },
                slave => {},
            },
        };
    }

    for my $cluster ( keys %{$config->{db}} ) {
        connect_cluster($config->{db}->{$cluster}, $cluster);
        $db->{$cluster}->{connected} = 1;
    }

    $db->{use_memcache} = $config->{use_memcache};
    $db->{config}       = $config;

    bless $db, $class;
}

sub memcached {
    $db->{memc} = $_[0];
}

sub connect_cluster {
    my( $cluster, $name ) = @_;

    connect_servers( $cluster->{master}, $name, 'm' );
    connect_servers( $cluster->{slave},  $name, 's' );
}

sub get_key {
    my( $name, $q ) = @_;

    $name = 'main' unless $name;

    $q = 'm' if $q eq 'master';
    $q = 's' if $q eq 'slave';

    return $name . '_' . $q;
}

sub connect_server {
    my( $server ) = @_;
    my $dbh;

    unless ( $ARGV[0] && $ARGV[0] eq 'test' ) {
        my $dsn = qq~dbi:mysql:database=$server->{base};host=$server->{host};port=$server->{port}~;
        if ($server->{socket}) { $dsn .= ';mysql_socket='.$server->{socket} }
        $dbh = DBI->connect(
            $dsn,
            $server->{user},
            $server->{pass},
            {
                AutoCommit             => 1,
                RaiseError             => 1,
                'mysql_enable_utf8'    => 1,
                'mysql_auto_reconnect' => 1,
                HandleError            => \&err_handler,
                FetchHashKeyName       => 'NAME_lc',
        }) or die $DBI::errstr;
        my $home = Mojo::Home->new;
        $home->detect;
#        DBI->trace('SQL', $home->rel_file('../log/database_sql.log'));
        $dbh->do("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED");
    }
    else {
        $dbh = DBI->connect( 'DBI:Mock:', '', '' );
    }

    return $dbh;
}

sub err_handler {
    my ($msg, $dbh, $ret) = @_;
    return 1 unless $print_errors;

    warn "$msg\n" . $dbh->{Statement} . "\nValues: " . Dumper( $dbh->{ParamValues} );
}

sub connect_servers {
    my( $servers, $number, $q ) = @_;
    my $key = get_key($number, $q);

    for my $server ( sort {$a <=> $b} keys %$servers ) {
        push @{$db->{$key}}, connect_server( $servers->{$server} );
    }
}

sub memc {
    return $db->{memc};
}

sub config {
    return $db->{config};
}

sub logger {
    my ($self, $message) = @_;
    my $log = Mojo::Log->new(path => $self->config->{logdir} . '/database_custom.log', level => 'info');
    $log->info($message);
}

sub pattern {
    my ($f, @tail) = @_;
    my @list = ref $f ? @$f : ($f, @tail);
    return '(' . join( ',', map {'?'} @list ) . ')';
}

sub print_errors {
    if ( @_ ) {
        $print_errors = $_[0];
    }
    else {
        return $print_errors;
    }
}

1;
