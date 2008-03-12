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

ThingFish::Resource - The perl ThingFish resource library

=head1 SYNOPSIS

 # Create a new ThingFish::Resource object.
 #
 my $resource = ThingFish::Resource->new;

 # Attach a file and some metadata to it.
 #
 $resource->data( '/path/to/file.jpg' );
 $resource->format( 'image/jpeg' );
 $resource->rating( 8 );

 # Save to a ThingFish server.
 #
 $resource->client( $thingfish_client );
 $resource->save;

 print $resource->uuid . "\n";


=head1 DESCRIPTION

This is the perl ThingFish resource library.  It handles fetching, modifying, and
saving a resource and its attributes.

=head1 DEPENDENCIES

Aside from some libraries that are included with perl, ThingFish::Resource also
requires:

    YAML::Syck

The 'yaml' filter must also be loaded on the ThingFish server.

=head1 METHODS

=over 4

=cut

#==============================================================================

package ThingFish::Resource;
use strict;
use warnings;

use YAML::Syck;
use IO::File;
use IO::String;
use File::Basename;

#==============================================================================

our $AUTOLOAD;

#==============================================================================

=item new()

Instantiate a new ThingFish::Resource object.

    $rs = ThingFish::Resource->new;
    $rs = ThingFish::Resource->new( '/path/to/file.jpg' );
    $rs = ThingFish::Resource->new( "data to store", $thingfish_client );

You may optionally instantiate the ThingFish::Resource with file data, and a
ThingFish::Client object to perform server communications.

=cut

sub new
{
	my ( $class, $data, $client ) = @_;

	my $self = {};
	bless $self, $class;

	$self->_reset;

	$self->client( $client ) if $client;
	$self->data( $data ) 	 if $data;

	return $self;
}


=item uuid()

    $uuid = $rs->uuid;

If this resource has been saved to the ThingFish server, uuid() will return its
unique identifier.  Otherwise, returns undef.

=cut

sub uuid { shift()->{ 'uuid' } }


=item client()

    $thingfish_client = $rs->client;
    $rs->client( $thingfish_client );

Associate a I<ThingFish::Client> object with this resource.  Returns the client
object.  This can also be performed via an argument to I<new()>.  A client object
association is required to perform any communication with the ThingFish server.  See
the I<ThingFish::Client> documentation for more info.

=cut

sub client
{
	my ( $self, $client ) = @_;
	if ( $client ) {
		unless ( ref $client eq 'ThingFish::Client' ) {
			$self->err( 'Argument to client() needs to be a ThingFish::Client object.' );
			return;
		}
		$self->{ '_client' } = $client;
	}
	return $self->{ '_client' };
}


=item err()

Returns the last recorded error message.

    $rs->update_properties or die 'Unable to update properties: ' . $rs->err . "\n";

=cut

sub err
{
	my ( $self, $err ) = @_;
	$self->{ '_err' } = $err if $err;
	return $self->{ '_err' };
}


=item get_property()

    $mimetype = $rs->get_property( 'format' );
    $filesize = $rs->get_property( 'extent' );

Fetch and return a metadata key.  Returns undef if the key doesn't exist.  This is a
default function for I<ThingFish::Resource> objects, so the following are equivalent:

    $checksum = $rs->checksum;
    $checksum = $rs->get_property( 'checksum' );

=cut

sub get_property
{
	my ( $self, $prop ) = @_;
	return unless $prop;
	$self->_fetch_metadata if 
		$self->uuid && ! scalar keys %{ $self->{ '_metadata' } };
	return $self->{ '_metadata' }->{ $prop };
}



=item get_properties()

Returns an array of all metadata keys for the resource.

    foreach my $prop ( $rs->get_properties ) {
        print "$prop: " . $rs->get_property( $prop ) . "\n";
    }

=cut

sub get_properties
{
	my $self = shift;
	$self->_fetch_metadata if
		$self->uuid && ! scalar keys %{ $self->{ '_metadata' } };
	return sort keys %{ $self->{ '_metadata' } };
}


=item set_property()

    $rs->set_property( 'format', 'image/jpeg' );
    $rs->set_property( 'exif_comment', 'yet another meme' );

Set a metadata key pair. This is a default function for I<ThingFish::Resource>
objects, so the following are equivalent:

    $rs->set_property( 'title', 'totally_rad_meme.jpg' );
    $rs->title( 'totally_rad_meme.jpg' );

Note that due to function character restrictions in perl, you would need to use the
explicit I<set_property()> function if the metadata key has dashes/spaces/etc.

=cut

sub set_property
{
	my ( $self, $prop, $value ) = @_;
	return unless $prop && defined $value;
	$self->{ '_dirty' }->{ 'metadata' } = 1;
	$self->{ '_metadata' }->{ $prop } = $value;
}



=item update_properties()

    @properties = $rs->update_properties;

Saves local changes to metadata back to the server.  Returns the array of metadata
keys.  On error, returns undef and sets I<err()>.  In most cases, you will probably
want to call I<save()> instead, which will also save local changes to file data.

Requires that the resource already exists on the server, and the resource has a
I<ThingFish::Client> association.

=cut

sub update_properties
{
	my $self = shift;
	unless ( $self->uuid ) {
		$self->err( "This resource doesn't have a UUID. (Need to call save()?)" );
		return;
	}

	# merge any file specific metadata from the server into
	# the locally modified hash.
	#
	if ( $self->{ '_generated_metadata' } ) {
		my %metadata = ( %{$self->{ '_generated_metadata' }}, %{$self->{ '_metadata' }} );
		$self->{ '_metadata' } = \%metadata;
		$self->{ '_generated_metadata' } = undef;
	}

	# no-op if we haven't changed anything locally.
	#
	return sort keys %{ $self->{ '_metadata' } } unless
		$self->{ '_dirty' }->{ 'metadata' };

	my $uri = $self->client->_handler_uri('simplemetadata');
	my $response = $self->client->_send_request(
		'PUT' => $uri . $self->uuid,
	   	{
			headers => [ content_type => 'text/x-yaml' ],
			content => YAML::Syck::Dump( $self->{ '_metadata' } )
		}
	);

	if ( $response->is_success ) {
		$self->{ '_metadata' } = YAML::Syck::Load( $response->content );
		$self->{ '_dirty' }->{ 'metadata' } = 0;
		return sort keys %{ $self->{ '_metadata' } };
	}
	else {
		$self->err( $response->status_line );
		return;
	}
}


=item save()

    $rs = $rs->save;

Saves all local resource changes to a ThingFish server.  Returns the resource object
after any server side manipulations.  On error, returns undef and sets I<err()>.

Requires the resource has a I<ThingFish::Client> association.

Uploads are buffered, so large files don't allocate their weight in memory.

=cut

sub save
{
	my $self = shift;
	unless ( $self->client ) {
		$self->err( "No ThingFish::Client object attached to this resource. Need to call client()?" );
		return;
	}

	return $self->client->store( $self );
}


=item revert()

    $rs->revert;

Destroy any local modifications to the resource object.

=cut

sub revert
{
	my $self = shift;
	$self->_reset;
}


=item export()

    $rs->export( '/path/to/save/spot/file.jpg' );

Convenience method for downloading and saving a resource locally.  Buffers the
download, so large files don't allocate their weight in memory.

=cut

sub export
{
	my $self = shift;
	my $file = shift or return;
	unless ( $self->uuid ) {
		$self->err( "This resource doesn't have a UUID. (Not saved to the server?)" );
		return;
	}

	my $uri = $self->client->_handler_uri('default');
	my $response = $self->client->_send_request(
		GET => $uri . $self->uuid,
		{
			headers => [ Accept => $self->{'_accept'} || '*/*' ],
			spool   => 1,
			export  => $file
		}
	);

	if ( $response->is_success ) {
		return 1;
	}
	else {
		$self->err( $response->status_line );
		return;
	}
}


=item data()

    my $io = $rs->data;
    $rs->data( '/path/to/file.jpg' );
    $rs->data( "inline data in a string" )	

Gets or sets file data for the resource.  You may pass either a string (slurped
binary data), or a path to a file on disk.  Returns either an IO::File or IO::String
object, which you may call I<read()> on to access the file data.

=cut

sub data
{
	my $self = shift;
	my $data = shift;

	# Convert all data references to IO:: objects.
	#
	# The rules for this:
	#	if a file path is provided and is valid (exists),
	#	it will become an IO::File object, and set $self->title.
	#	Otherwise, it becomes an IO::String.
	#
	# We could have used perl 5.8 open() semantics here,
	# but opted to maintain compatibility with earlier
	# perl versions.
	#
	if ( $data ) {
		if ( -e $data ) {
			my $size = -s _;
			$self->{ '_data' } = IO::File->new( $data, 'r' );
			$self->title( File::Basename::fileparse( $data ) );
			$self->extent( $size );
		}
		else {
			$self->{ '_data' } = IO::String->new( $data );
			$self->extent( length($data) );
		}
		$self->{ '_dirty' }->{ 'filedata' } = 1;
	}
	else {

		# This resource was created via a pull from a ThingFish server.
		# Fetch the data from the server.
		#
		if ( $self->uuid && ! $self->{ '_data' } ) {
			my $uri = $self->client->_handler_uri('simplemetadata');
			my $response = $self->client->_send_request(
				GET => $uri . $self->uuid,
				{
					headers => [ Accept => $self->{'_accept'} || '*/*' ],
					spool   => 1
				}
			);

			# $response->content is now a spooled IO::File object.
			#
			$self->{ '_data' } = $response->content;
			$self->{ '_dirty' }->{ 'filedata' } = 0;
		}
	}

	return $self->{ '_data' };
}


### Grab metadata on a UUID, and associate the UUID with 
### the resource object.  Called by ThingFish::Client->fetch.
###
sub _load
{
	my ( $self, $uuid, $accept ) = @_;
	$self->{ 'uuid' }    = $uuid;
	$self->{ '_accept' } = $accept;
	return $self->_fetch_metadata ? 1 : 0;
}


### Revert all local changes to the resource object.
### Further accesses to metadata or filedata will lazy load
### from the ThingFish server.
###
sub _reset
{
	my $self = shift;
	$self->{ '_metadata' } = {};
	$self->{ '_data'  }    = undef;
	$self->{ '_dirty' }    = { 'metadata' => 0, 'filedata' => 0 };
}


### Pull down and cache metadata from the ThingFish server.
###
sub _fetch_metadata
{
	my $self = shift;
	my $uri = $self->client->_handler_uri('simplemetadata');
	my $response = $self->client->_send_request( GET => $uri . $self->uuid );

	if ( $response->is_success ) {
		$self->{ '_metadata' } = YAML::Syck::Load( $response->content );
		$self->{ '_dirty' }->{ 'metadata' } = 0;
		return $self->{ '_metadata' };
	}
	else {
		$self->err( $response->status_line );
		return;
	}
}


### Unknown functions are assumed to be metadata property
### get/set accessors.
###
sub DESTROY {}
sub AUTOLOAD
{
	my $prop = $AUTOLOAD;
	$prop =~ s/.*:://;

	my $self  = shift;
	my $value = shift;

	if ( $value ) {
		return $self->set_property( $prop, $value );
	}
	else {
		return $self->get_property( $prop );
	}
}

1;

=back

=head1 AUTHORS

Mahlon E. Smith I<mahlon@martini.nu> and Michael Granger I<ged@faeriemud.org>.

=cut

