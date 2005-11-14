package Catalyst::Plugin::Session::State::URI;
use base qw/Catalyst::Plugin::Session::State/;

use strict;
use warnings;

use NEXT;
use URI::Find;
use URI::Escape ();

our $VERSION = "0.01";

sub finalize {
    my $c = shift;

    if ( $c->session_should_rewrite ) {
        if ( $c->response->body and my $sid = $c->sessionid ) {
            URI::Find->new(
                sub {
                    my ( $uri_obj, $found_text ) = @_;
                    $c->session_should_rewrite_uri( $uri_obj, $found_text )
                      ? $c->uri_with_sessionid($found_text)
                      : $found_text;
                }
            )->find( \$c->response->{body} );
        }
    }

    return $c->NEXT::finalize(@_);
}

sub session_should_rewrite { 1 }

sub uri_with_sessionid {
    my ( $c, $uri ) = @_;
    return join( "/-/", $uri, URI::Escape::uri_escape( $c->sessionid ) );
}

sub session_should_rewrite_uri {
    my ( $c, $uri_obj, $uri_text ) = @_;

    return
      index( $uri_text, $c->request->base ) == 0 # if URI is pointing to our app
      && ( $uri_obj->path !~ m#/-/# );    # and it isn't already rewritten
}

sub prepare_action {
    my $c = shift;

    if ( $c->request->path =~ m#^ (?: (.*) / )? -/ (.+) $#x ) {
        $c->request->path( defined $1 ? $1 : "" );
        $c->sessionid($2);
        $c->log->debug(qq/Found sessionid "$2" in uri/) if $c->debug;
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

In the future this may be conditional based on the type of the body, or other
factors. For now it returns true, and it's separate so that you can overload
it.

=item session_should_rewrite_uri $uri_obj, $uri_text

This method is called from the L<URI::Find> callback to determine whether a URI
should be rewritten.

It will return true for URIs that point under C<$c->req->base), which do not

=item uri_with_sessionid $uri_text

This method takes any URI B<string> and appends C</-/$sessionid> to it.

have the string C</-/> in them yet.

=back

=head1 EXTENDED METHODS

=over 4

=item prepare_action

Will restore the session if the request URI is formatted accordingly, and
rewrite the URI to remove the additional part.

=item finalize

If C<session_should_rewrite> returns a true value, L<URI::Find> is used to
replace all URLs which point to C<< $c->request->base >> so that they contain
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
C<http://yourapp/link/http://the_url_of_whatever/foo.html>).

=back

But note that this behavior will be problematic when you are e.g. submitting
POSTs to forms on external sites.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Session>,
L<Catalyst::Plugin::Session::FastMmap>, C<URI::Find>.

=head1 AUTHORS

This module is derived from L<Catalyst::Plugin::Session::FastMmap> code, and
has been heavily modified since.

Andrew Ford
Andy Grundman
Christian Hansen
Yuval Kogman, C<nothingmuch@woobling.org>
Marcus Ramberg
Sebastian Riedel

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
