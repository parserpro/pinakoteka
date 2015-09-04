package Helpers::Util;
use common::sense;

my $user_events_types = {
    autor                => 1,
    work                 => 2,
    edition              => 3,
    publisher            => 4,
    translator           => 5,
    art                  => 6,
    award                => 7,
    contest              => 8,
    recomendations       => 9,
    antologies_list      => 10,
    series_list          => 11,
    autors_list          => 12,
    rating_autor         => 13,
    rating_work          => 14,
    rating_gender        => 15,
    rating_lp            => 16,
    works_by_genre       => 17,
    blogs_list           => 18,
    blogs_last_posts     => 19,
    blogs_subscribed     => 20,
    blogs_article_show   => 21,
    forum_list           => 22,
    forum_topics         => 23,
    forum_topic_show     => 24,
    publisher_plan       => 25,
    film                 => 26,
    dictor               => 27,
    award_list           => 28,
    user_list            => 29,
    serie                => 30,
    autor_all_responses  => 31,
    autor_all_editions   => 32,
    autor_all_awards     => 33,
    autor_all_ratings    => 34,
    autor_all_film       => 35,
    crossautorcycleslist => 36,
    fantastikovedenie    => 37,
    blogs_user           => 38,
    blogs_articles       => 39,

    reviews_last         => 40,
    reviews_user         => 41,
    bookcase_list        => 42,
    bookcase_show        => 43,
};

my $admin_events_types = {
    autor                => 1,
    translator           => 2,
    art                  => 3,
    dictor               => 4,
    work                 => 5,
    edition              => 6,
    publisher            => 7,
    serie                => 8,
    award                => 9,
    contest              => 10,
    nomination           => 11,
    contest_work         => 12,
    film                 => 13,
    article              => 14,
};

my $admin_events_actions = {
    add     => 1,
    edit    => 2,
    remove  => 3,
};

sub setup {
    my ($name, $self) = @_;

    $self->app->helper( 'redirect_url'       => \&redirect_url );
    $self->app->helper( 'logger'             => \&logger );
    $self->app->helper( 'render_error'       => \&render_error );
    $self->app->helper( 'add_metric_event'   => \&add_metric_event );
    $self->app->helper( 'add_admin_event'    => \&add_admin_event );
    $self->app->helper( 'find_route_name'    => \&find_route_name );
    $self->app->helper( 'switch_nano_url'    => \&switch_nano_url );
    $self->app->helper( 'is_mobile_browser'  => \&is_mobile_browser );
    $self->app->helper( 'content_for_static' => \&content_for_static );
    $self->app->helper( 'get_static_file'    => \&get_static_file );
    $self->app->helper( 'get_static_block'    => \&get_static_block );
}

# редирект-ссылка
sub redirect_url {
    my $self = shift;

    my $referrer = Mojo::URL->new($self->req->headers->referrer || '')->path;

    return $referrer;
}

# использовать логгер
sub logger {
    my ($self, $message) = @_;
    my $log = Mojo::Log->new(path => $self->config->{logdir} . '/fantlab.log', level => 'info');
    $log->info($message);
}

# показать окно с ошибкой
sub render_error {
    my ($self, $error) = @_;

    $self->stash(error_text => $error);
    $self->render('errors/error', status => 400, layout => '');
}

# добавить метрику
sub add_metric_event {
    my ($self, $metric_type, %params) = @_;

    return unless $self->config->{is_metrics_enabled};

    my $user_id = Profile->id;
    my $ip_address = $self->req->headers->header('X-Real-IP') || $self->tx->remote_address;

    # определение реферрера
    my $referrer = '';
    my $redirect_url = $self->req->headers->referrer ?  Mojo::URL->new($self->req->headers->referrer) : undef;
    my $external_link = '';

    if ($redirect_url) {
        $external_link = ($self->url_for->to_abs->host ne $redirect_url->host ? 1 : 0) if $redirect_url;
        $referrer = $self->find_route_name($redirect_url?$redirect_url->path:'') unless $external_link;
        $referrer = $redirect_url->path if $referrer eq 'act'; # костыль для старых роутов
        $referrer = $redirect_url->host if $external_link; # внешние ссылки
    }

    $metric_type = $user_events_types->{$metric_type} || $metric_type;

    BD::Misc->add_metric_event($user_id, $ip_address, $metric_type, $referrer, \%params);
}

sub add_admin_event {
    my ($self, $metric_type, %params) = @_;

    my $user_id = Profile->id;
    my $ip_address = $self->req->headers->header('X-Real-IP') || $self->tx->remote_address;

    if ($params{action}) {
        $params{action} = $admin_events_actions->{$params{action}};
    }

    BD::Misc->add_admin_event($user_id, $ip_address, $admin_events_types->{$metric_type}||$metric_type, \%params);
}

# найти имя роута по его пути
sub find_route_name {
    my ($self, $path) = @_;

    my $match = Mojolicious::Routes::Match->new(root => $self->app->routes);
    $match->find($self => {method => 'GET', path => $path });

    return $match->endpoint->name;
}

# изменить ссылку на мобильную версию
sub switch_nano_url {
    my ($self, $url) = @_;
    return '' unless $url;

    my $url = Mojo::URL->new($url);
    my $url_str;

    if ($url->host =~ /^nano\.(.*)$/) {
        $url_str = $url->host($1);
    }
    else {
        my $host = '';

        if ( $url->host =~ /^www\.(.*)$/) {
            $host = $1;
        }
        else {
            $host = $url->host;
        }

        $host = 'nano.' . $host;
        $url_str = $url->host($host);
    }

    $url_str =~ s/^(http|htpps)\://;
    return $url_str;
}

# проверка на мобильную версию
sub is_mobile_browser {
    my ($self, $user_agent_string) = @_;

    # кривой способ. не работает на ipad и на android планшетах. мобильный - не значит маленький экран!
    #my $browser = HTTP::BrowserDetect->new($user_agent_string);
    #return $browser->mobile;

    if ( $user_agent_string =~ m/android.+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i ) {
        return 1
    }
}

# подгрузка дополнительных скриптов
sub content_for_static {
    my ($self, @statics) = @_;

    my ($content_css, $content_js);

    # чтобы один и тот же файл не прописывался несколько раз, если его затребовали разные внутренние шаблоны
    my %statis_file_hash = ();
    my $hash_ref = $self->stash('content_for_static_files');
    %statis_file_hash = %$hash_ref if ($hash_ref);

    foreach my $file (@statics) {
        # юзать минифицированные версии для прода
        # if ($self->app->mode eq 'production' && $file =~ /(.*)\.(css|js)$/) {
        #     $file = $1 . '.min.' . $2;
        # }
        next if ($statis_file_hash{$file});
        $statis_file_hash{$file} = 1;
        my $timestamp = $self->static_timestamp->{"static_timestamp:$file"};
        next unless ($timestamp); # если пусто, значит нет такого файла
        if ($file =~ /\.css$/) {
            $content_css .= qq{<link href="/css/$file?t=$timestamp" rel="stylesheet" />\n};
        }
        elsif ($file =~ /.\js$/) {
            $content_js .= qq{<script src="/js/$file?t=$timestamp"></script>\n};
        }
    }
    $self->stash(content_for_static_files => \%statis_file_hash);

    $self->content_for(mojo_styles => $content_css);
    $self->content_for(mojo_scripts => $content_js);

    return;
};

sub get_static_file {
    my ($self, $file) = @_;
    my $timestamp = $self->static_timestamp->{"static_timestamp:$file"};
    return $file.($timestamp?"?t=$timestamp":'');
}

sub get_static_block {
    my ($self, $file) = @_;
    my $timestamp = $self->static_timestamp->{"static_timestamp:$file"};
    return unless ($timestamp);
    my $code = '';
    if ($file =~ /\.js$/) {
        return qq{<script src="/js/$file?t=$timestamp"></script>};
    } elsif ($file =~ /\.css$/) {
        return qq{<link href="/css/$file?t=$timestamp" rel="stylesheet" />};
    } else {
        return;
    }
}

1;