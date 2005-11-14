#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 29;
use Test::MockObject::Extends;
use URI::Find;

my $m;
BEGIN { use_ok( $m = "Catalyst::Plugin::Session::State::URI" ) }

{

    package HashObj;
    use base qw/Class::Accessor/;

    __PACKAGE__->mk_accessors(qw/body path base/);
}

my $req = Test::MockObject::Extends->new( HashObj->new );
$req->base("http://server/app/");

my $res = Test::MockObject::Extends->new( HashObj->new );

my $external_uri         = "http://www.woobling.org/";
my $internal_uri         = $req->base . "somereq";
my $internal_uri_with_id = "${internal_uri}/-/foo";

my $cxt =
  Test::MockObject::Extends->new("Catalyst::Plugin::Session::State::URI");

$cxt->set_always( request  => $req );
$cxt->set_always( response => $res );
$cxt->set_false("debug");
my $sessionid;
$cxt->mock( sessionid => sub { shift; $sessionid = shift if @_; $sessionid } );

can_ok( $m, "session_should_rewrite" );
ok( $cxt->session_should_rewrite, "sessions should rewrite by default" );

foreach my $uri (qw{ any http://string/in http://the/world/ }) {
    $sessionid = "foo";
    can_ok( $m, "uri_with_sessionid" );
    is( $cxt->uri_with_sessionid($uri), "${uri}/-/foo" );
    $sessionid = undef;
}

can_ok( $m, "session_should_rewrite_uri" );

ok(
    $cxt->session_should_rewrite_uri( URI->new($internal_uri), $internal_uri ),
    "internal URIs should be rewritten"
);

ok(
    !$cxt->session_should_rewrite_uri(
        URI->new($internal_uri_with_id),
        $internal_uri_with_id
    ),
    "already rewritten internal URIs should not be rewritten again"
);

ok(
    !$cxt->session_should_rewrite_uri( URI->new($external_uri), $external_uri ),
    "external URIs should not be rewritten"
);

can_ok( $m, "prepare_action" );

$cxt->clear;
$req->path("somereq");

$cxt->prepare_action;
ok( !$cxt->called("sessionid"),
    "didn't try setting session ID when there was nothing to set it by" );

is( $req->path, "somereq", "req path unchanged" );

$req->path("some_req/-/the session id");
ok( !$cxt->sessionid, "no session ID yet" );
$cxt->prepare_action;
is( $cxt->sessionid, "the session id", "session ID was restored from URI" );
is( $req->path,      "some_req",       "request path was rewritten" );

$sessionid = undef;
$req->path("-/the session id");    # sri's bug
ok( !$cxt->sessionid, "no session ID yet" );
$cxt->prepare_action;
is(
    $cxt->sessionid,
    "the session id",
    "session ID was restored from URI with empty path"
);
is( $req->path, "", "request path was rewritten" );

can_ok( $m, "finalize" );

$res->body("foo");
$cxt->finalize;
is( $res->body, "foo", "body unchanged with no URLs" );

$res->body( my $body_ext_url = "foo $external_uri blah" );
$cxt->finalize;
is( $res->body, $body_ext_url, "external URL stays untouched" );

$res->body( my $body_internal = "foo $internal_uri bar" );
$cxt->finalize;

like( $res->body, qr#^foo $internal_uri.* bar$#, "body was rewritten" );

my @uris;
URI::Find->new( sub { push @uris, $_[0] } )->find( \$res->body );

is( @uris, 1, "one uri was changed" );
is(
    "$uris[0]",
    $cxt->uri_with_sessionid($internal_uri),
    "rewritten to output of uri_with_sessionid"
);

$cxt->set_false("session_should_rewrite");

$res->body($body_internal);
$cxt->finalize;
is( $res->body, $body_internal,
    "no rewriting when 'session_should_rewrite' returns a false value" );

