#!/usr/bin/env perl
# vim: set nosta noet ts=4 sw=4:
#
# Little example command line ThingFish client.
#
# Requires the FreeDesktop mime magic library:
#	http://www.freedesktop.org/wiki/Software/shared-mime-info
#

use strict;
use warnings;
use lib '.';
use ThingFish::Client;
use ThingFish::Resource;
use File::MimeInfo::Magic;

usage() unless scalar @ARGV;
sub usage
{
	print <<EOF;
Usage:
  $0 THINGFISH_URL info
  $0 THINGFISH_URL upload FILE
  $0 THINGFISH_URL check UUID
  $0 THINGFISH_URL fetch UUID [FILE]
  $0 THINGFISH_URL properties UUID
  $0 THINGFISH_URL update UUID FILE
  $0 THINGFISH_URL search PROPERTY VALUE [, PROP, VAL ...]
EOF
	exit 1;
}

my $url  = shift @ARGV;
my $verb = shift @ARGV;

my $tf = ThingFish::Client->new;
do {
	$url =~ s|^https?://||i;
	my ( $host, $port ) = split ':', $url;
	usage() unless $host && $port;
	$tf->host( $host );
	$tf->port( $port );
};

info() if $verb eq 'info';
usage() unless scalar @ARGV;

upload()     if $verb eq 'upload';
check()      if $verb eq 'check';
fetch()      if $verb eq 'fetch';
properties() if $verb eq 'properties';
update()     if $verb eq 'update';
search()     if $verb eq 'search';
usage();

sub info
{
	my $info = $tf->_serverinfo;
	
	printf "ThingFish at %s:%d is a version %s server.\n",
		$tf->host, $tf->port, $tf->server_version;
		
	print "\nHandlers:\n";
	printf "%20s -> [ %s ]\n",
		'default', ( join ', ', @{$info->{ 'handlers' }->{ 'default' }} );
	foreach my $handler ( keys %{ $info->{ 'handlers' } }) {
		next if $handler eq 'default';
		printf "%20s -> [ %s ]\n",
			$handler, ( join ', ', @{$info->{ 'handlers' }->{ $handler }} );
	}
	print "\nFilters:\n";
	foreach my $filter ( keys %{ $info->{ 'filters' } }) {
		my $filter_info = $info->{'filters'}->{ $filter };
		printf "  %s v%s (rev %d)\n",
			$filter, ( join '.', @{$filter_info->{ 'version' }} ), $filter_info->{ 'rev' };
	}	
	exit 0;
}

sub check
{
	my $uuid = shift @ARGV;
	return unless is_valid_uuid( $uuid );
	print $tf->has( $uuid ) ? "Yep!\n" : "Nope!\n";
	exit 0;
}

sub upload
{
        foreach ( @ARGV ) {
            my $rs   = ThingFish::Resource->new( $_, $tf );
            my $mime = File::MimeInfo::Magic::magic( $rs->data );
            $rs->format( $mime );
            $rs->save or die $rs->err . "\n";
            printf "OK: %s -> %s\n", $rs->uuid, $rs->title;
        }
	exit 0;
}

sub fetch
{
	my $uuid = shift @ARGV or return;
	my $file = shift @ARGV;
	return unless is_valid_uuid( $uuid );

	my $rs = $tf->fetch( $uuid ) or die $tf->err . "\n";
	my $name = $file || $rs->title || 'untitled_data';
	$rs->export( $name ) or die $rs->err . "\n";
	
	print "OK: $name\n";
	exit 0;
}

sub properties
{
	my $uuid = shift @ARGV or return;
	return unless is_valid_uuid( $uuid );
	my $rs = $tf->fetch( $uuid ) or die $tf->err . "\n";

	foreach my $prop ( $rs->get_properties ) {
		print "$prop: " . $rs->get_property( $prop ) . "\n";
	}
	exit 0;
}

sub update
{
	my $uuid = shift @ARGV or return;
	my $file = shift @ARGV or return;
	return unless is_valid_uuid( $uuid );

	my $rs = $tf->fetch( $uuid ) or die $tf->err . "\n";
	$rs->data( $file );

	my $mime = File::MimeInfo::Magic::magic( $rs->data );
	$rs->format( $mime );

	$rs->save or die $rs->err . "\n";
	print 'OK: ' . $rs->uuid . "\n";
	exit 0;
}

sub search
{
	foreach ( $tf->find( @ARGV ) ) {
		print $_->uuid;
		print ': ' . $_->title if $_->title;
		print "\n" 
	}
	exit 0;
}

sub is_valid_uuid
{
	my $uuid = shift;
	return $uuid =~ $ThingFish::Client::uuid_regexp;
}

