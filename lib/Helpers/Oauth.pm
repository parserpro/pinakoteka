package Helpers::Oauth;
use common::sense;

use Data::Dumper;

sub setup {
    my ($name, $self) = @_;

    $self->app->helper( 'oauth_access'  => \&oauth_access );
}

# Проверка доступа к ресурсу с текущей oauth авторизацией (передается через заголовки HTTP запроса)
# Возвращает:
#   0 - если нет доступа
#   1 - если есть доступ
sub oauth_access {
  my ($self, $token, $resource) = @_;

  if (defined($token) && !BD::OauthToken->expired($token)) {
    my @token_resources = split(',', $token->{resources});
    foreach my $res (@token_resources) {
        return 1 if $res eq $resource;
    };
  };
  $self->logger("[ERROR] [OAUTH] Access error for resorce '".$resource."'");
  return 0;
};

1;