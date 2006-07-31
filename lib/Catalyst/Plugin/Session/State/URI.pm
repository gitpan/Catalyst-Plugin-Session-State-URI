package Catalyst::Plugin::Session::State::URI;
use base qw/Catalyst::Plugin::Session::State Class::Accessor::Fast/;

use strict;
use warnings;

use HTML::TokeParser::Simple;
use MIME::Types;
use NEXT;
use URI;
use URI::QueryParam;

our $VERSION = "0.04";

__PACKAGE__->mk_accessors("_sessionid_from_uri");

sub get_session_id {
    my $c = shift;
    return $c->_sessionid_from_uri;
}

sub setup_session {
    my $c = shift();

    $c->NEXT::setup_session(@_);
    unless ( exists( $c->config->{session}{rewrite} ) ) {
        $c->config->{session}{rewrite} = 1;
    }
}

sub finalize {
    my $c = shift;

    if ( $c->session_should_rewrite ) {
        if ( $c->response->body and my $sid = $c->sessionid ) {
            my $p =
              HTML::TokeParser::Simple->new( string => $c->response->body );
            my $body = '';
            while ( my $token = $p->get_token ) {

                # deal with <a href="">
                if ( $token->is_start_tag('a') ) {
                    my $href = $token->get_attr('href');
                    $href = $c->uri_with_sessionid($href)
                      if $c->session_should_rewrite_uri($href);
                    $token->set_attr( 'href', $href );
                }

                # deal with <form action="">
                if ( $token->is_start_tag('form') ) {
                    my $action = $token->get_attr('action');
                    $action = $c->uri_with_sessionid($action)
                      if $c->session_should_rewrite_uri($action);
                    $token->set_attr( 'action', $action );
                }
                $body .= $token->as_is;
            }
            $c->response->body($body);
        }
    }

    return $c->NEXT::finalize(@_);
}

sub session_should_rewrite {
    my $c = shift();

    return $c->config->{session}{rewrite};
}

sub uri_for {
    my ( $c, $path, @args ) = @_;
                
    return $c->config->{session}{overload_uri_for}
        ? $c->uri_with_sessionid($c->NEXT::uri_for($path, @args))
        : $c->NEXT::uri_for($path, @args);
} 

sub uri_with_sessionid {
    my ( $c, $uri ) = @_;

    my $uri_obj = eval { URI->new($uri) } || return $uri;

    return $c->config->{session}{param}
      ? $c->uri_with_param_sessionid($uri_obj)
      : $c->uri_with_path_sessionid($uri_obj);
}

sub uri_with_param_sessionid {
    my ( $c, $uri_obj ) = @_;

    my $param_name = $c->config->{session}{param};

    $uri_obj->query_param( $param_name => $c->sessionid );

    return $uri_obj;
}

sub uri_with_path_sessionid {
    my ( $c, $uri_obj ) = @_;

    $uri_obj->path( join( "/-/", $uri_obj->path, $c->sessionid ) );

    return $uri_obj;
}

sub session_should_rewrite_uri {
    my ( $c, $uri_text ) = @_;

    my $uri_obj = eval { URI->new($uri_text) } || return;

    # ignore the url outside
    my $rel = $uri_obj->abs( $c->request->base );
    return unless index( $rel, $c->request->base ) == 0;

    # ignore media type such as gif, pdf and etc
    if ( $rel =~ m#\.(\w+)(?:\?|$)# ) {
        my $mt = new MIME::Types->mimeTypeOf($1);
        return
          if ref $mt && ( $mt->isBinary || $mt->mediaType eq 'text' );
    }

    if ( my $param = $c->config->{session}{param} )
    {    # use param style rewriting

        # if the URI query string doesn't contain $param
        return not defined $uri_obj->query_param($param);

    } else {    # use path style rewriting

        # if the URI isn't already rewritten
        return $uri_obj->path !~ m#/-/#;

    }
}

sub prepare_action {
    my $c = shift;

    if ( my $param = $c->config->{session}{param} )
    {           # use param style rewriting

        if ( my $sid = $c->request->param($param) ) {
            $c->_sessionid_from_uri($sid);
            $c->log->debug(qq/Found sessionid "$sid" in query parameters/)
              if $c->debug;
        }

    } else {    # use path style rewriting

        if ( my ( $path, $sid ) = ( $c->request->path =~ m{^ (?: (.*) / )? -/ (.+) $}x )  ) {
            $c->request->path( defined($path) ? $path : "" );
            $c->log->debug(qq/Found sessionid "$sid" in uri path/)
              if $c->debug;
            $c->_sessionid_from_uri($sid);
        }

    }

    $c->NEXT::prepare_action(@_);
}

__PACKAGE__

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session::State::URI - Saves session IDs by rewriting URIs
delivered to the client, and extracting the session ID from requested URIs.

=head1 SYNOPSIS

    use Catalyst qw/Session Session::State::URI Session::Store::Foo/;

    # If you want the param style rewriting, set the parameter
    MyApp->config->{session} = {
        param   => 'sessionid', # or whatever you like
    };

=head1 DESCRIPTION

In order for L<Catalyst::Plugin::Session> to work the session ID needs to be
stored on the client, and the session data needs to be stored on the server.

This plugin cheats and instead of storing the session id on the client, it
simply embeds the session id into every URI sent to the user.

=head1 METHODS

=over 4

=item session_should_rewrite

This method is consulted by C<finalize>. The body will be rewritten only if it
returns a true value.

It will read C<$c-E<gt>config-E<gt>{session}{rewrite}> which will be set 1 at first if not defined.
In the future this may be conditional based on the type of the body, or other
factors. And it's separate so that you can overload it.

=item session_should_rewrite_uri $uri_text

This method is to determine whether a URI should be rewritten.

It will return true for URIs under C<$c-E<gt>req-E<gt>base>, and it will also use L<MIME::Types> to filter the links which point to png, pdf and etc with the file extension.

=item uri_with_sessionid $uri_text

By path style rewriting, it will appends C</-/$sessionid> to the uri path.

http://myapp/link -> http://myapp/link/-/$sessionid

By param style rewriting, it will add a parameter key/value pair after the uri path.

http://myapp/link -> http://myapp/link?$param=$sessionid

=back

=head1 EXTENDED METHODS

=over 4

=item prepare_action

Will restore the session if the request URI is formatted accordingly, and
rewrite the URI to remove the additional part.

=item finalize

If C<session_should_rewrite> returns a true value, L<HTML::TokePaser::Simple> is used to
traverse the body to replace all URLs which get true returned by C<session_should_rewrite_uri> so that they contain
the session ID.

=back

=head1 CAVEATS

=head2 Session Hijacking

URI sessions are very prone to session hijacking problems.

Make sure your users know not to copy and paste URIs to prevent these problems,
and always provide a way to safely link to public resources.

Also make sure to never link to external sites without going through a gateway
page that does not have session data in it's URI, so that the external site
doesn't get any session IDs in the http referrer header.

Due to these issues this plugin should be used as a last resort, as
L<Catalyst::Plugin::Session::State::Cookie> is more appropriate 99% of the
time.

Take a look at the IP address limiting features in L<Catalyst::Plugin::Session>
to see make some of these problems less dangerous.

=head3 Goodbye page recipe

To exclude some sections of your application, like a goodbye page (see
L</CAVEATS>) you should make extend the C<session_should_rewrite_uri> method to
return true if the URI does not point to the goodbye page, extend
C<prepare_action> to not rewrite URIs that match C</-/> (so that external URIs
with that in their path as a parameter to the goodbye page will not be
destroyed) and finally extend C<uri_with_sessionid> to rewrite URIs with the
following logic:

=over 4

=item *

URIs that match C</^$base/> are appended with session data (
C<< $c->NEXT::uri_with_sessionid >>).

=item *

External URIs (everything else) should be prepended by the goodbye page. (e.g.
C<http://myapp/link/http://the_url_of_whatever/foo.html>).

=back

But note that this behavior will be problematic when you are e.g. submitting
POSTs to forms on external sites.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Session>,L<Catalyst::Plugin::Session::FastMmap>
C<HTML::TokeParser::Simple>, C<MIME::Types>.

=head1 AUTHORS

This module is derived from L<Catalyst::Plugin::Session::FastMmap> code, and
has been heavily modified since.

=item Andrew Ford

=item Andy Grundman

=item Christian Hansen

=item Yuval Kogman, C<nothingmuch@woobling.org>

=item Marcus Ramberg

=item Sebastian Riedel

=item Hu Hailin

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
