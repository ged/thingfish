#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'

	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/filter_behavior'

	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/filter/rfc2822'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

describe ThingFish::Rfc2822Filter do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
		@datadir = Pathname.new( __FILE__ ).dirname.parent.parent + 'data'
	end
		
	before( :each ) do
		@filter = ThingFish::Filter.create( 'rfc2822' )
	end

	after( :all ) do
		reset_logging()
	end

	
	### Shared behaviors
	it_should_behave_like "A Filter"

	describe " with a simple message body" do

		SIMPLE_MESSAGE_METADATA = {
			:rfc822_content_transfer_encoding => "7bit",
			:rfc822_content_type => "text/plain; charset=utf-8",
			:rfc822_date => "Mon, 10 Sep 2007 18:14:30 -0700",
			:rfc822_delivered_to => "mailing list klonkweasel@lists.squidge.com",
			:rfc822_from => "Example User <example@squidge.com>",
			:rfc822_mailing_list => "contact klonkweasel-help@lists.squidge.com; run by ezmlm",
			:rfc822_message_id => "<6410929.583831189473270716.JavaMail.root@zimbra01.squidge.com>",
			:rfc822_mime_version => "1.0",
			:rfc822_received =>
				"; Mon, 10 Sep 2007 18:14:31 -0700\n"\
				"from unknown by lists.squidge.com with SMTP; Mon, 10 Sep 2007 18:14:31 -0700\n"\
				"from localhost by zimbra01.squidge.com with ESMTP id 2B947C92A62 "\
					"for <klonkweasel@lists.squidge.com>; Mon, 10 Sep 2007 18:14:31 -0700\n"\
				"from zimbra01.squidge.com by localhost with ESMTP id I0zZQHBFhqvx "\
					"for <klonkweasel@lists.squidge.com>; Mon, 10 Sep 2007 18:14:31 -0700\n"\
				"by zimbra01.squidge.com id 037F0C9315E; Mon, 10 Sep 2007 18:14:31 -0700\n"\
				"from zimbra01.squidge.com by zimbra01.squidge.com with ESMTP id EB0B7C92A62 "\
					"for <klonkweasel@squidge.com>; Mon, 10 Sep 2007 18:14:30 -0700",
			:rfc822_return_path => "<example@squidge.com>",
			:rfc822_subject => "Dishwasher Status",
			:rfc822_to => "klonkweasel <klonkweasel@squidge.com>",
			:rfc822_x_originating_ip => "[10.5.1.74]",
			:rfc822_x_spam_level => "",
			:rfc822_x_spam_score => "-4.384",
			:rfc822_x_spam_status => "No, score=-4.384 tagged_above=-10 required=4 " \
				"tests=[ALL_TRUSTED=-1.8, AWL=0.015, BAYES_00=-2.599]",
			:rfc822_x_virus_scanned => "amavisd-new at ",
		  }
		

		before( :each ) do
			@testmessage = (@datadir + 'simple.eml').open

			@response = stub( "response object" )

			@request_metadata = { :format => 'message/rfc822' }
			@request = mock( "request object" )
			@request.stub!( :http_method ).and_return( 'POST' )
			@request.stub!( :each_body ).and_yield( @testmessage, @request_metadata )
		end

		it "can extract mail-message headers to prefixed metadata" do
			@request.should_receive( :append_metadata_for ).with( @testmessage, SIMPLE_MESSAGE_METADATA )
			@filter.handle_request( @request, @response )
		end
	
	end


	describe " with a multipart/mixed message body" do

		MIXED_MESSAGE_METADATA = {
			:rfc822_received => "; Tue, 11 Sep 2007 16:27:42 -0700\n"\
				"from unknown by lists.squidge.com with SMTP; Tue, 11 Sep 2007 16:27:42 -0700\n"\
				"from localhost by zimbra01.squidge.com with ESMTP id ED0B4216000B; "\
					"Tue, 11 Sep 2007 16:27:41 -0700\n"\
				"from zimbra01.squidge.com by localhost with ESMTP id mKCdZN8190wR; "\
					"Tue, 11 Sep 2007 16:27:41 -0700\n"\
				"by zimbra01.squidge.com id 33C4A2160006; Tue, 11 Sep 2007 16:27:41 -0700\n"\
				"from zimbra01.squidge.com by zimbra01.squidge.com with ESMTP id 19DC12160005; "\
					"Tue, 11 Sep 2007 16:27:41 -0700",
			:rfc822_delivered_to => "mailing list klonkweasel@lists.squidge.com",
			:rfc822_x_spam_score => "-4.064",
			:rfc822_return_path => "<example@squidge.com>",
			:rfc822_x_spam_status => "No, score=-4.064 tagged_above=-10 required=4 "\
				"tests=[ALL_TRUSTED=-1.8, AWL=-0.040, BAYES_00=-2.599, HTML_30_40=0.374, "\
				"HTML_MESSAGE=0.001]",
			:rfc822_from => "Example User <example@squidge.com>",
			:rfc822_in_reply_to => "<26710539.674321189553026355.JavaMail.root@zimbra01.squidge.com>",
			:rfc822_subject => "9.11.07 Weekly SQUIDGE Media Update",
			:rfc822_x_virus_scanned => "amavisd-new at ",
			:rfc822_mailing_list => "contact klonkweasel-help@lists.squidge.com; run by ezmlm",
			:rfc822_to => "klonkweasel <klonkweasel@squidge.com>, "\
				"Sleepy Dwarf <sleepy@dwarves.com>, "\
				"Gargleflop Bothangus <gb@example.com>, "\
				"Kalmditch Reiser <kalmrei@example.com>, "\
				"Harthunk Lidlin <hl33212@example.net>, "\
				"Bingo Karsomovic <daddylongtoes@example.com>, "\
				"Yin Yhinhintinamin <jjunk@example.com>, "\
				"Quasitenbithelen Snookeri <otherguy@example.com>",
			:rfc822_message_id => "<21021437.674731189553260979.JavaMail.root@zimbra01.squidge.com>",
			:rfc822_content_type=>'multipart/mixed; '\
				'boundary="----=_Part_16039_15903964.1189553260972"',
			:rfc822_x_originating_ip => "[10.4.1.96]",
			:rfc822_mime_version => "1.0",
			:rfc822_x_spam_level => "",
			:rfc822_date => "Tue, 11 Sep 2007 16:27:40 -0700",
		  }


		before( :each ) do
			@testmessage = (@datadir + 'mixed.eml').open

			@response = stub( "response object" )

			@request_metadata = { :format => 'message/rfc822' }
			@request = mock( "request object" )
			@request.stub!( :http_method ).and_return( 'POST' )
			@request.stub!( :each_body ).and_yield( @testmessage, @request_metadata )
		end


		it "extracts resources from interesting parts of the message body" do
			plaintext = stub( "plaintext part" )
			html = stub( "html part" )
			pdf = stub( "pdf part" )

			# Multipart/alternative doc
			@request.should_receive( :append_metadata_for ).with( @testmessage, {
				:rfc822_content_type=>'multipart/alternative; '\
					'boundary="----=_Part_16040_3327739.1189553260972"'
			  } )

			StringIO.should_receive( :new ).with( /^\s*Hello!\s*Style Tip/m ).and_return( plaintext )
			@request.should_receive( :append_related_resource ).with( @testmessage, plaintext, {
				:format => "text/plain",
				:relation => "part_of",
				:rfc822_content_transfer_encoding => "Quoted-printable",
			  } )
			StringIO.should_receive( :new ).with( /<html><head>/i ).and_return( html )
			@request.should_receive( :append_related_resource ).with( @testmessage, html, {
				:relation => "part_of",
				:format => "text/html",
				:rfc822_content_transfer_encoding => "Quoted-printable",
			  } )
			StringIO.should_receive( :new ).with( /^%PDF-1.5/ ).and_return( pdf )
			@request.should_receive( :append_related_resource ).with( @testmessage, pdf, {
				:title => "THR_blood2.pdf",
				:format => "application/pdf",
				:rfc822_content_transfer_encoding => "Base64",
				:relation => "part_of"
			  } )

			@request.should_receive( :append_metadata_for ).
				with( @testmessage, MIXED_MESSAGE_METADATA )
			@filter.handle_request( @request, @response )
		end
	
	end

end

# vim: set nosta noet ts=4 sw=4:
