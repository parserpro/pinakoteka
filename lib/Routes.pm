package Routes;
use common::sense;

use Data::Dumper;

sub setup_routing {
    my $self = shift;

    # роут будет работать для всех
    my $r = $self->routes;

    # роут будет работать ТОЛЬКО для авторизированных пользователей
    $r->add_condition(login => sub {
        my ($route, $c, $captures, $pattern) = @_;

        return 1 if Profile->id;

        return;
    });

    # роут будет работать ТОЛЬКО для администраторов
    $r->add_condition(admin => sub {
        my ($route, $c, $captures, $pattern) = @_;

        if (Profile->access_to_admin_functions) {
            $c->stash(
                menuaction => 'admin',
                tabheader  => 'Администрирование'
            );
            return 1;
        }

        return;
    });

    # роут будет работать ТОЛЬКО через HTTPS
    $r->add_condition(https => sub {
        my ($route, $c, $captures, $pattern) = @_;

        return 1 if $c->req->headers->header('X-Forwarded-HTTPS') || ($c->config->{disabled} && $c->config->{disabled}->{https_protection});
        return;
    });

    # домашняя страница
    # расширенная запить to() используется только для наглядности
    # рекомендуется везде писать так $r->route(...)->to('home#index')
    $r->route('/')->to(controller => 'home', action => 'index');

    # сохранение файла
    $r->route('/save')->via('POST')->to('file#save');
}

1;
