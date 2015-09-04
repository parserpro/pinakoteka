package Pinakoteka;
use Mojo::Base 'Mojolicious';
use Mojo::Headers;
use Mojo::Loader qw(find_modules load_class);
use Mojo::Cache;
use common::sense;
use BD;
use Time::HiRes qw(time);
use Functions::Util;
use Routes;
use POSIX qw(strftime setlocale LC_ALL LC_CTYPE);

has dbh => sub {
    my $self = shift;
    return BD->get_global_master;
};

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin('Config' => {dir => $self->home->to_string . '/config/'});

    $self->setup_hooks;
    Routes::setup_routing($self);
    $self->setup_modules;

    # настройка сессий (перенести в подходящее место)
    $self->secrets([$self->config->{secret}]);
#    $self->sessions->cookie_name('sessioncode');
#    $self->sessions->default_expiration(60 * 60 * 24 * 365);
#    $self->sessions->cookie_domain($self->config->{cookiedomain}); # '.fantlab.ru'

    $self->defaults(layout => 'default');

    $self->types->type(form => 'application/x-www-form-urlencoded');

    # формат вывода логов
    $self->log->format(sub {
        return '[' . localtime(shift) . '] ' . "[$$]" . ' [' . shift() . '] ' . join("\n", @_, '');
    });
}

sub setup_hooks {
    my $self = shift;

    # выполняется перед обработкой каждого запроса
    $self->app->hook(before_dispatch => sub {
        my $c = shift;

        $c->stash(start_time => time);

        # запуск профайлера
        if ( $c->param('nytprof') && $c->param('nytprof') eq 'qwe' ) {
            DB::enable_profile($c->config->{logdir} . '/' . Profile->id . ':' . time . ':' . $$ . '.out' );
        }

        # константы
        $c->stash (
            referrer       => "/",
        );

        # если https, дать нужную схему для редиректов
        $c->req->url->base->scheme('https') if $c->req->headers->header('X-Forwarded-HTTPS');

        # чтобы видеть action в ps aux
        $0 = $c->config->{process_name} . ' ' . $c->param('action');
    });

    $self->app->hook(after_dispatch => sub {
        my $c = shift;

        # остановка профайлера
        if ( $c->param('nytprof') && $c->param('nytprof') eq 'qwe' ) {
            DB::disable_profile();
            DB::finish_profile();
        }

        $c->stash(end_time => time);
    });
}

sub setup_modules {
    my $self = shift;

    load_class 'Memcached';
    my $memcached = Memcached->connect_memcached;

    # база данных - модель
    for my $module ( find_modules 'BD' ) {
        my $e = load_class $module;
        warn qq{Loading "$module" failed: $e} and next if ref $e;
    }

    $self->helper( 'memcached' => sub { return $memcached });

    for my $module ( find_modules 'Functions' ) {
        my $e = load_class $module;
        warn qq{Loading "$module" failed: $e} and next if ref $e;
    }

    for my $module ( find_modules 'Helpers' ) {
        my $e = load_class $module;
        warn qq{Loading "$module" failed: $e} and next if ref $e;
        $module->setup($self);
    }
}

1;
