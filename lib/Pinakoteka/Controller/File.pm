package Pinakoteka::Controller::File;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(url_escape);
use Data::Dumper;

# This action will render a template
sub save {
    my $c = shift;

    $c->render(json => { status => 'error', message => 'File is too big (16 Mb is upper limit)'})
      if $c->req->is_limit_exceeded;

    return $c->redirect_to('/') unless my $file = $c->param('file');
    my $name = $file->filename;
    $file->move_to($c->config->{filedir} . '/' . $name);

    $c->render(json => { status => 'ok', name => $name, size => $file->size, link => '//file/' . url_escape $name });
}

1;
