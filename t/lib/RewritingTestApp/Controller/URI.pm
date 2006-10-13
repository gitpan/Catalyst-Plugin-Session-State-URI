#!/usr/bin/perl

package RewritingTestApp::Controller::URI;

use strict;
use warnings;

use Test::More; # love singletons (sometimes)

use base qw/Catalyst::Controller/;

sub first_request : Global {
    my ( $self, $c ) = @_;

    ok( !$c->session_is_valid, "no session" );

    $c->session->{counter} = 1;

    $c->forward("add_some_html");
}

sub second_request : Global {
    my ( $self, $c ) = @_;

    ok( $c->session_is_valid, "session exists" );

    is( ++$c->session->{counter}, 2, "counter is OK" );

    $c->forward("add_some_html");
}


sub third_request : Global {
    my ( $self, $c ) = @_;

    ok( $c->session_is_valid, "session exists" );

    is( ++$c->session->{counter}, 3, "counter is OK" );

    $c->forward("add_some_html");
}

sub add_some_html : Private {
    my ( $self, $c ) = @_;

    # no using uri_for, because it's overloaded

    my $counter = $c->session->{counter};

    $c->response->content_type("text/html");
    $c->response->body( <<HTML );
<html>
    <head>
        <title>I like Moose</title>
    </head>
    <body>

        counter: $counter

        <a href="/second_request">second</a>
        <a href="/third_request">third</a>
    </body>
</html>
HTML
}

sub text_request : Global {
    my ( $self, $c ) = @_;

    $c->session->{counter} = 42;
    $c->forward("add_some_html");

    $c->response->content_type("text/plain") if $c->request->param("plain");
}

__PACKAGE__;

__END__
