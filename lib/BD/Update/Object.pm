package BD::Update::Object;
use common::sense;
use utf8;

my %cache;
my $database;
my ($real, $show);

my %sql = (
    'BD::Update::Schema' => sub { 'SELECT * FROM INFORMATION_SCHEMA.SCHEMATA WHERE schema_name = ?' },
    'BD::Update::Table'  => sub { 'DESCRIBE `' . $_[0] . '`' },
    'BD::Update::Column' => sub { 'SHOW FULL COLUMNS FROM `' . $_[0] . '` LIKE ?' },
    'BD::Update::Index'  => sub { 'SHOW INDEX FROM `' . $_[0] . '` WHERE key_name = ?' },
);

my %sql_drop = (
    'BD::Update::Table'  => sub { 'DROP TABLE IF EXISTS `' . $_[0] . '`' },
    'BD::Update::Column' => sub { 'ALTER TABLE `' . $_[0] . '` DROP COLUMN `' . $_[1] . '`' },
#    Index  => sub { 'SHOW INDEX FROM `' . $_[0] . '` WHERE key_name = ?' },
);

my %params = (
    'BD::Update::Schema' => sub { $_[0] },
    'BD::Update::Table'  => sub { () },
    'BD::Update::Column' => sub { $_[1] },
    'BD::Update::Index'  => sub { $_[1] },
);

sub new {
    my ( $class, $table, $name ) = @_;
    return unless $main::dbh;

    $table = $database if $class eq 'BD::Update::Schema';
    return unless $table;

    $table = ref $table ? $table->{table} : $table;
    return $cache{$class}->{$table}          if exists $cache{$class}->{$table} && ! $name;
    return $cache{$class}->{$table}->{$name} if exists $cache{$class}->{$table} && exists $cache{$class}->{$table}->{$name};

    my $res;

    eval {
        $res  = $main::dbh->selectall_arrayref( $sql{$class}->($table, $name), {Slice => {}}, $params{$class}->($table, $name) );
    };

    if ( $@ ) {
        warn "ERROR: $@";
    }

    if ( $main::dbh->err ) {
        unless ( $main::dbh->errstr =~ /Table .+ doesn\'t exist/ ) {
            warn "leave, error: " . $main::dbh->errstr;
        }

        return;
    }

    my $obj = {
        table => $table,
        (
            $name
              ? (name => $name)
              : ()
        ),
        def   => $res,
        class => $class,
    };

    bless $obj, $class;

    $class eq 'BD::Update::Table' || $class eq 'BD::Update::Schema'
      ? $cache{$class}->{$table} = $obj
      : $cache{$class}->{$table}->{$name} = $obj;
    return $obj;
}

sub exists {
    my $obj = shift;
    return unless $obj;
    return @{$obj->{def}} ? 1 : 0;
}

sub invalidate {
    my $obj = shift;
    my $class = ref $obj;

    if ( $class eq 'BD::Update::Table' ) {
        delete $cache{'BD::Update::Table'}->{$class->{name}};
        delete $cache{'BD::Update::Column'}->{$class->{name}};
        delete $cache{'BD::Update::Index'}->{$class->{name}};
    }
    else {
        delete $cache{ref $class}->{$class->{table}}->{$class->{name}};
    }
}

sub alter {
    my ($object, $sql) = @_;

    if ( $show ) {
        say "SQL: $sql";
    }

    if ( $real ) {
        $main::dbh->do($sql);
        $object->invalidate;
    }
}

sub init {
    my ( undef, %params ) = @_;

    $real = 1 if exists $params{real} && $params{real};
    $show = 1 if exists $params{show} && $params{show};
    ($database) = $main::dbh->selectrow_array('SELECT DATABASE()');
    return $database;
}

sub drop {
    my $object = shift;
    return if $object->{class} eq 'Schema';

    my $sql = $sql_drop{$object->{class}}->($object->{table}, $object->{name});

    if ( $object->{class} eq 'Column' && $object->{def}->[0]->{key} eq 'PRI' ) {
        $sql .= ', DROP PRIMARY KEY'
    }

    if ( $show ) {
        say "SQL: $sql";
    }

    if ( $real ) {
        $main::dbh->do($sql);
    }

    $object->invalidate;
}

1;
