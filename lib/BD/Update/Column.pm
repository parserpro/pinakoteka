package BD::Update::Column;
use common::sense;
use utf8;
use base 'BD::Update::Object';

use Exporter 'import';
our @EXPORT = qw(column);

sub column {
    return __PACKAGE__->SUPER::new(@_);
}

sub has_type {
    my ($column, $type) = @_;
    return unless $column;
    return $column->type eq lc($type) ? 1 : 0;
}

sub type {
    my $column = shift;
    return unless $column;
    return lc($column->{def}->[0]->{type});
}

sub default {
    my $column = shift;
    return unless $column;
    return lc($column->{def}->[0]->{default});
}

1;
