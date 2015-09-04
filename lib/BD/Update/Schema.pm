package BD::Update::Schema;
use common::sense;
use utf8;

use base 'BD::Update::Object';
use BD::Update::Table;

use Exporter 'import';
our @EXPORT = qw(schema);

our %cache;

sub schema {
    return __PACKAGE__->SUPER::new(@_);
}

sub collation {
    my $schema = shift;
    return unless $schema;
    return $schema->{def}->[0]->{default_collation_name};
}

sub chars {
    my $schema = shift;
    return unless $schema;
    return $schema->{def}->[0]->{default_character_set_name};
}

sub init {
    return __PACKAGE__->SUPER::init(@_);
}

1;
