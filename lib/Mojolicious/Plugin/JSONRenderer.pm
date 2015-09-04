package Mojolicious::Plugin::JSONRenderer;
use Mojo::Base 'Mojolicious::Plugin';
use JSON::XS;
use common::sense;

sub register {
    my ($self, $app) = @_;

    # rewrite json handler
    $app->renderer->add_handler(json => sub {
      my ($renderer, $c, $output, $options) = @_;

      my $xs = JSON::XS->new->utf8->pretty(1)->canonical;

      $$output = $xs->encode($options->{json});

      return 1;
    });
  }

1;