package CLI;
use common::sense;

use 5.10.0;
use utf8;

my $dir;

BEGIN {
    $dir = $ENV{PINA_HOME};
}

use lib "$dir/lib";

use Mojo::Base 'Pinakoteka';
use Mojolicious;
use open ':std', ':encoding(UTF-8)';

# Делаем приложение (обязательно)
my $self = Mojolicious->new->secrets(['superawfulsalt4_pina']);
push @{$self->renderer->paths}, "$dir/templates";
$self->plugin('Config' => {dir => "$dir/config/"});
$Fantlab::mojo = $self;
BD->connect_all($self->config);
my $dbh = BD->get_global_master;
Pinakoteka::setup_modules($self);
my $memcached = BD::memc();

# Делаем контроллер (только если рендерим шаблоны)
my $mojo = $Fantlab::mojo = Mojolicious::Controller->new->app( $self );

$|++;

# Export
*main::dbh = \$dbh;
*main::dir = \$dir;
*main::self = \$self;
*main::memcached = \$memcached;
*main::mojo = \$mojo;
*main::ISA = \@Pinakoteka::CLI::ISA;
BD::print_errors(0);

1;
