#
# vim: set nosta noet ts=4 sw=4:
#
# Copyright (c) 2008,
#       Mahlon E. Smith <mahlon@martini.nu>
#       Michael Granger <ged@faeriemud.org>
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the names of the authors nor the names of the
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=pod

=head1 NAME

ThingFish::Client - The perl ThingFish client library

=head1 SYNOPSIS

 # Connect to a ThingFish server running at localhost.
 #
 my $tf = ThingFish::Client->new;

 # Find all mp3 files in the store, and save them locally.
 #
 foreach my $uuid ( $tf->find( format => 'audio/mpeg' ) ) {
	my $resource = $tf->fetch( $uuid ) or die $tf->err;
        $resource->export( $resource->title );
 
	printf "Saved mp3 %s (%s, %0.2fK %s)\n",
		$resource->title, $resource->format,
		$resource->extent / 1024, $resource->checksum;
 }

=head1 DESCRIPTION

This is the perl ThingFish client library.  It handles communications with a backend
ThingFish server.

=head1 DEPENDENCIES

Aside from some libraries that are included with perl, ThingFish::Client also
requires:

    LWP (libwww)
    YAML::Syck

The 'yaml' filter must also be loaded on the ThingFish server.

=head1 METHODS

=over 4

=cut

#==============================================================================

package ThingFish::Client;
use strict;
use warnings;

use ThingFish::Resource;
use LWP;
use IO::Socket;
use YAML::Syck;
use File::Temp;
use URI;

#==============================================================================

my $version      = '0.1';
my $svnrev       = '$Rev$';
my $agent        = "thingfish-client $version-$svnrev/perl";
our $uuid_regexp = qr/[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}/i;
my $buffersize   = 16384;

#==============================================================================

=item new()

Instantiate a new ThingFish::Client object.

    $tf = ThingFish::Client->new;
    $tf = ThingFish::Client->new('hostname');
    $tf = ThingFish::Client->new( host => 'hostname', port => 80, ... );

=cut

sub new
{
	my ( $class, @options ) = @_;

	my $self = {};
	my $opts = {};

	$opts->{ 'host' } = shift @options if scalar @options == 1;
	%$opts = @options if scalar @options;

	$self->{ 'spooldir' } = $opts->{ 'spooldir' } || '.';

	$self->{ 'uri' } = URI->new;
	$self->{ 'uri' }->scheme( 'http' );
	$self->{ 'uri' }->host( $opts->{ 'host' } || 'localhost' );
	$self->{ 'uri' }->port( $opts->{ 'port' } || 3474 );

	$self->{ '_err' } = '';

	bless  $self, $class;
	return $self;
}


=item err()

Returns the last recorded error message from the server.

    $tf->has( $uuid ) or die "No such UUID, server said: " . $tf->err . "\n";

=cut

sub err
{
	my ( $self, $err ) = @_;
	$self->{ '_err' } = $err if $err;
	return $self->{ '_err' };
}


=item server_version()

Return the ThingFish server version.

=cut

sub server_version
{
	my $self = shift;
	return $self->_serverinfo->{ 'version' };
}


=item host()

Set a new ThingFish hostname, or return the current one.

    $tf->host( 'localhost' );
    $host = $tf->host;

=cut

sub host
{
	my ( $self, $host ) = @_;
	$self->{ 'uri' }->host( $host ) if $host;
	return $self->{ 'uri' }->host;
}


=item port()

Set a new ThingFish server port, or return the current one.

    $client->port( 80 );
    $port = $client->port;

=cut

sub port
{
	my ( $self, $port ) = @_;
	$self->{ 'uri' }->port( $port ) if $port;
	return $self->{ 'uri' }->port;
}


=item has()

Ask the ThingFish server if a particular resource exists.
Returns a boolean.

    if ( $tf->has('fe04ddfc-d4ce-11dc-8031-0016cba18fb9') ) {
        print "The server has the resource!\n";
    }
    else {
        print "Awww, no such resource.\n";
    }

=cut

sub has
{
	my ( $self, $uuid ) = @_;
	return 0 unless $uuid && $uuid =~ $uuid_regexp;

	my $uri = $self->_handler_uri('simplemetadata') or return;

	my $response = $self->_send_request( HEAD => "$uri/$uuid" );
	unless ( $response->is_success ) {
		$self->err( $response->status_line );
		return 0;
	}
	return 1;
}


=item fetch()

Load a resource from the ThingFish server.
Returns a I<ThingFish::Resource> object.

    $resource = $tf->fetch('fe04ddfc-d4ce-11dc-8031-0016cba18fb9');

You can pass an Accept mimetype as a second argument to retrieve
the content in a different format.  (This requires server side support.)

    $resource_as_jpg = $tf->fetch('fe04ddfc-d4ce-11dc-8031-0016cba18fb9', 'image/jpeg');

=cut

sub fetch
{
	my ( $self, $uuid, $accept ) = @_;

	# verify uuid
	unless ( $uuid && $uuid =~ $uuid_regexp ) {
		$self->err( "Invalid UUID: $uuid" );
		return;
	}

	my $resource = ThingFish::Resource->new;
	$resource->client( $self );
	return $resource if $resource->_load( $uuid, $accept );

	$self->err( $resource->err );
	return;
}


=item store()

Store a I<ThingFish::Resource> to the ThingFish server.
Returns the resource, with additional server generated metadata.

    $resource = ThingFish::Resource->new( $filename );
    $resource->some_extra_metadata( 'yah!' );
    $resource = $tf->store( $resource );

=cut

sub store
{
	my ( $self, $resource ) = @_;
	unless ( ref $resource eq 'ThingFish::Resource' ) {
		$self->err( 'Argument to store() must be a ThingFish::Resource' );
		return;
	}

	# Send the resource data to the ThingFish server.
	#
	if ( $resource->{ '_dirty' }->{ 'filedata' } ) {
		$self->_storedata( $resource ) or return;
	}

	# We had a successful upload, so send a separate request
	# to attach any added metadata.
	#
	# TODO: Atomic POST via multipart.
	#
	$resource->update_properties;
	return $resource;
}


=item find()

Takes an array of term pairs, returns an array of matching UUIDs
as ThingFish::Resource objects.

    @uuids = $tf->find( format => 'image/*', title => '*drunk*' );

=cut

sub find
{
	my ( $self, @search_terms ) = @_;

	my $uri = $self->_handler_uri('simplesearch') or return;
	my $response = $self->_send_request(
		GET => $uri, { query_args => \@search_terms }
	);

	if ( $response->is_success ) {
		my $uuids = YAML::Syck::Load( $response->content );
		my @resources = ();
		
		foreach ( @$uuids ) {
			my $resource = ThingFish::Resource->new;
			$resource->client( $self );
			$resource->{ 'uuid' } = $_;
			push @resources, $resource;
		}
		return @resources;
				
	}
	else {
		$self->err( $response->status_line );
		return;
	}
}


### Server introspection.
### Parse and cache the content at /.
###
sub _serverinfo
{
	my $self = shift;
	return $self->{ '_serverinfo' } if $self->{ '_serverinfo' };

	my $response = $self->_send_request( GET => '/' );

	if ( $response->is_success ) {
		$self->{ '_serverinfo' } = YAML::Syck::Load( $response->content );
	}
	else {
		$self->err( $response->status_line );
		return;
	}

	return $self->{ '_serverinfo' };
}


### Use server introspection to find the required handlers.
###
### $self->_handler_uri('simplesearch') == '/search'
###
sub _handler_uri
{
	my $self    = shift;
	my $handler = shift;

	my $info = $self->_serverinfo;
	unless ( $info && ref $info->{ 'handlers' } eq 'HASH' ) {
		$self->err( 'Unable to determine handler map via server intropection.' );
		return;
	}

	my $handlers = $info->{ 'handlers' };
	my $uris     = $handlers->{ $handler };
	return ref $uris eq 'ARRAY' ? $uris->[0] : undef;
}

### Build and cache the local UserAgent object.
###
sub _ua
{
	my $self = shift;
	return $self->{ '_ua' } if $self->{ '_ua' };

	my $ua = LWP::UserAgent->new;
	$ua->agent( $agent );

	# Request content in YAML as a default.
	#
	my $headers = HTTP::Headers->new( Accept => 'text/x-yaml' );
	$ua->default_headers( $headers );

	$self->{ '_ua' } = $ua;
	return $ua;
}


### Workhorse wrapper for handling communication with the ThingFish server.
###
sub _send_request
{
	my ( $self, $method, $path, $opts ) = @_;
	$opts = $opts || {};

	# Build URI
	#
	my $uri = $self->{ 'uri' }->clone;
	$uri->path( $path );
	$uri->query_form( $opts->{ 'query_args' } ) if $opts->{ 'query_args' };

	my $headers = HTTP::Headers->new( @{$opts->{ 'headers' }} );
	my $request = HTTP::Request->new( uc($method) => $uri, $headers );

	$request->content( $opts->{ 'content' } );

	if ( $self->{ '_debug' } ) {
		print '-' x 50 . "\n";
		print $request->as_string;
		print "\n\n";
	}

	# Support buffered writes to disk.  Optionally
	# return an IO::File object representing the response body.
	#
	my $response;
	if ( $opts->{ 'spool' } ) {
		my $filename = $opts->{ 'export' } ?
			$opts->{ 'export' } :
			File::Temp::tempnam( $self->{ 'spooldir' }, 'tf-XXXXXX' );
		$response = $self->_ua->request( $request, $filename );
		$response->content( IO::File->new( $filename, 'r' ) );
		unlink $filename unless $opts->{ 'export' };
	}
	else {
		$response = $self->_ua->request( $request );
	}
	print $response->as_string if $self->{ '_debug' };
	return $response;
}


### It looks as if HTTP::Request supports buffered downloads natively,
### but not uploads.  This method is used in place of HTTP::Response
### for any file data streaming -to- the server.
###
sub _storedata
{
	my ( $self, $resource ) = @_;

	# Determine method.  If the resource already has a uuid, then
	# we update via PUT.  Otherwise, it's a new storage request,
	# and we POST.
	#
	my ( $method, $uri );
	if ( $resource->uuid ) {
		$method = 'PUT';
		$uri    = '/' . $resource->uuid;
	}
	else {
		$method = 'POST';
		$uri    = '/';
	}

	# build HTTP::Headers
	#
	my @headers = (
		user_agent     => $agent,
		accept         => 'text/x-yaml',
		content_length => $resource->extent
	);

	push @headers, content_type => $resource->format if $resource->format;
	if ( $resource->title ) {
		my $disposition = 'filename="' . $resource->title . '"';
		push @headers, content_disposition => $disposition;
	}
	my $action = "$method $uri HTTP/1.0\r\n";
	my $header = HTTP::Headers->new( @headers )->as_string;
	$header =~ s/\n/\r\n/g;
	$header .= "\r\n";

	if ( $self->{ '_debug' } ) {
		print '-' x 50 . "\n";
		print $header;
		print "\n\n";
	}

	# We can't buffer content writes to HTTP::Request,
	# so lets just send the data a little more manually.
	#
	my $s = IO::Socket::INET->new(
		PeerAddr => $self->host,
		PeerPort => $self->port,
		Proto    => 'tcp'
	);
	unless ( $s ) {
		$self->err( "Unable to contact ThingFish server: $!" );
		return;
	}

	# ship it off, buffered write.
	#
	my $buf;
	$s->send( $action . $header );
	$resource->data->seek(0,0); # make sure we start at the... start.
	while ( $resource->data->read( $buf, $buffersize ) ) {
		while ( $buf ) {
			my $sent = $s->send( $buf );
			unless ( defined( $sent ) ) {
				$self->err( "Socket error while sending data: $!" );
				return;
			}
			substr( $buf, 0, $sent, '' );
		}
	}

	# parse the response.
	#
	my $response;
	$response .= $_ while <$s>;
	$s->close;
	$response = HTTP::Response->parse( $response );
	print $response->as_string if $self->{ '_debug' };

	if ( $response->is_success ) {
		$resource->{ '_generated_metadata' } = YAML::Syck::Load( $response->content );
		if ( $method eq 'POST' ) {
			my $uuid = $response->header( 'location' );
			$uuid =~ s/^\///;

			# set necessary Resource attributes
			#
			$resource->{ 'uuid' } = $uuid;
			$resource->client( $self );
		}
	}
	else {
		$self->err( $response->status_line );
		return;
	}

	return $resource;
}

1;

=back

=head1 AUTHORS

Mahlon E. Smith I<mahlon@martini.nu> and Michael Granger I<ged@faeriemud.org>.

=cut
