#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rbconfig'

require 'rspec'

require 'spec/lib/helpers'
require 'spec/lib/filter_behavior'

require 'thingfish'
require 'thingfish/filter'

begin
	require 'thingfish/filter/rfc2822'
	$tmail_loaderror = nil
rescue LoadError => err
	$tmail_loaderror = err

	class ThingFish::Rfc2822Filter; end
end


#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

describe ThingFish::Rfc2822Filter do

	before( :all ) do
		setup_logging( :fatal )
		@datadir = Pathname.new( __FILE__ ).dirname.parent.parent + 'data'
	end

	before( :each ) do
		if $tmail_loaderror
			pending "installation of the tmail gem (%s)" % [ $tmail_loaderror.message ]
		end
		@filter = ThingFish::Filter.create( 'rfc2822' )
	end

	after( :all ) do
		reset_logging()
	end


	### Shared behaviors
	it_should_behave_like "a filter"

	describe " with a simple message body" do

		before( :each ) do
			@testmessage = (@datadir + 'simple.eml').open

			@response = stub( "response object" )

			@request_metadata = { :format => 'message/rfc822' }
			@request = mock( "request object" )
			@request.stub!( :http_method ).and_return( :POST )
			@request.stub!( :each_body ).and_yield( @testmessage, @request_metadata )
		end


		it "extracts metadata keys from the mail headers" do
			metadata = nil
			@request.should_receive( :append_metadata_for ).and_return {|msg, md| metadata = md }

			@filter.handle_request( @request, @response )

			metadata[ :'rfc822:content_transfer_encoding' ].should == "7bit"
			metadata[ :'rfc822:content_type' ].should == "text/plain; charset=utf-8"
			metadata[ :'rfc822:delivered_to' ].should == "mailing list klonkweasel@lists.squidge.com"
			metadata[ :'rfc822:from' ].should == "Example User <example@squidge.com>"
			metadata[ :'rfc822:mailing_list' ].
				should == "contact klonkweasel-help@lists.squidge.com; run by ezmlm"
			metadata[ :'rfc822:message_id' ].
				should == "<6410929.583831189473270716.JavaMail.root@zimbra01.squidge.com>"
			metadata[ :'rfc822:mime_version' ].should == "1.0"
			metadata[ :'rfc822:return_path' ].should == "<example@squidge.com>"
			metadata[ :'rfc822:subject' ].should == "Dishwasher Status"
			metadata[ :'rfc822:to' ].should == "klonkweasel <klonkweasel@squidge.com>"
			metadata[ :'rfc822:x_originating_ip' ].should == "[10.5.1.74]"
			metadata[ :'rfc822:x_spam_level' ].should == ""
			metadata[ :'rfc822:x_spam_score' ].should == "-4.384"
			metadata[ :'rfc822:x_spam_status' ].should == "No, score=-4.384 tagged_above=-10 required=4 " \
				"tests=[ALL_TRUSTED=-1.8, AWL=0.015, BAYES_00=-2.599]"
			metadata[ :'rfc822:x_virus_scanned' ].should == "amavisd-new at "

			metadata[ :'rfc822:date' ].should =~ /\w+, \d+ \w+ \d{4} \d\d:\d\d:\d\d [+\-]\d{4}/
			metadata[ :'rfc822:received' ].should =~ %r{lists.squidge.com with SMTP}
			metadata[ :'rfc822:received' ].should =~ %r{zimbra01.squidge.com with ESMTP id 2B947C92A62}
		end

	end


	describe " with a multipart/mixed message body" do

		before( :each ) do
			@testmessage = (@datadir + 'mixed.eml').open

			@response = stub( "response object" )

			@request_metadata = { :format => 'message/rfc822' }
			@request = mock( "request object" )
			@request.stub!( :http_method ).and_return( :POST )
			@request.stub!( :each_body ).and_yield( @testmessage, @request_metadata )
		end


		it "extracts resources from interesting parts of the message body" do
			plaintext = stub( "plaintext part" )
			html = stub( "html part" )
			pdf = stub( "pdf part" )

			# Multipart/alternative doc
			@request.should_receive( :append_metadata_for ).with( @testmessage, {
				:'rfc822:content_type'=>'multipart/alternative; '\
					'boundary="----=_Part_16040_3327739.1189553260972"'
			  } )

			StringIO.should_receive( :new ).with( /^\s*Hello!\s*Style Tip/m ).and_return( plaintext )
			@request.should_receive( :append_related_resource ).with( @testmessage, plaintext, {
				:format => "text/plain",
				:relation => "part_of",
				:'rfc822:content_transfer_encoding' => "Quoted-printable",
			  } )
			StringIO.should_receive( :new ).with( /<html><head>/i ).and_return( html )
			@request.should_receive( :append_related_resource ).with( @testmessage, html, {
				:relation => "part_of",
				:format => "text/html",
				:'rfc822:content_transfer_encoding' => "Quoted-printable",
			  } )
			StringIO.should_receive( :new ).with( /^%PDF-1.5/ ).and_return( pdf )
			@request.should_receive( :append_related_resource ).with( @testmessage, pdf, {
				:title => "THR_blood2.pdf",
				:format => "application/pdf",
				:'rfc822:content_transfer_encoding' => "Base64",
				:relation => "part_of"
			  } )

			@request.should_receive( :append_metadata_for ).
				with( @testmessage, an_instance_of(Hash) )
			@filter.handle_request( @request, @response )
		end

	end

end

# vim: set nosta noet ts=4 sw=4:
