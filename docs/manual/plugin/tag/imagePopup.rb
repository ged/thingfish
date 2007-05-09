# 
# Popup CSS viewer plugin for the ThingFish manual
# 

require 'pathname'

begin
	require 'RMagick'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	# Ignore -- RMagick is optional
end


# Includes a file verbatim. All HTML special characters are escaped.
class ImagePopupTag < Tags::DefaultTag

	DEFAULT_THUMBNAIL_WIDTH = 250
	CSS_RULES = <<-END.gsub(/^\t/, '')
	/* --- imagePopup plugin --------------------------- */
	@import url(thickbox.css);
	/* ------------------------------------------------- */
	END

	infos( :name => 'Tag/ImagePopup',
		:author => "Monkeys",
		:summary => "Show an image in a popup container (ThickBox)"
	)

	param 'image', nil, %q{The name of the image file which should be displayed}
	param 'title', nil, %q{The title of the thumbnail tag or the link text if } +
		%q{RMagick isn't installed}
	param 'thumbnailWidth', DEFAULT_THUMBNAIL_WIDTH, %q{The width of the thumbnails } +
		%q{to generate for the image (if RMagick is installed).}


	set_mandatory 'image', true

	register_tag 'imagePopup'


	### Create a new imagePopup tag plugin.
	def initialize( plugin_manager )
		plugin_manager['Core/ResourceManager'].append_data( 'webgen-css', CSS_RULES )
		@have_magick = Object.const_defined?( :Magick )

		super
	end
	

	### Process the specified +tag+ in the given +chain+.
	def process_tag( tag, chain )
		srcfile = Pathname.new( chain.first.node_info[:src] )
		imagefile = srcfile.dirname + param('image')
		title = param('title') || 
			imagefile.basename( imagefile.extname ).to_s.gsub( /[\W\s]+/, ' ' )
		html = nil

		if @have_magick
			thumbname, height, width = make_thumbnail( srcfile, imagefile )
			html = %{<a href="%s" title="%s" class="thickbox"><img src="%s" alt="%s" } %
				[ imagefile.relative_path_from(srcfile.dirname), title, thumbname, title ]
			html += %{height="%d" width="%d" /></a>} % [ height, width ]
		
		else
			html = %{<a href="%s" title="%s" class="thickbox">Image: %s</a>} %
				[ imagefile.relative_path_from(srcfile.dirname), title, title ]
		end

		return html
	rescue RuntimeError => err
		log( :error ) { "%s: %s" % [ err.class.name, err.message ] }
	end


	#######
	private
	#######

	### Create a thumbnail of the specified image and return its name, height, and 
	### width
	def make_thumbnail( srcfile, imagefile )
		raise NotImplementedError, "No RMagick on this system" unless @have_magick
		thumbnail = imagefile.dirname + "%s_t%s" %
			[ imagefile.basename(imagefile.extname), imagefile.extname ]
		thumb = nil

		# Use the pre-existing one if possible
		if thumbnail.exist? && imagefile.mtime <= thumbnail.mtime
			thumb = Magick::Image.read( thumbnail ).first
			
		# Build a new one
		else
			img = Magick::Image.read( imagefile ).first
		
			new_width = param('thumbnailWidth') || DEFAULT_THUMBNAIL_WIDTH
			scale =  new_width / img.columns.to_f

			log( :debug ) {
				"Generating thumbnail for %dx%d image: scale factor is %0.2f%%" %
				[ img.columns, img.rows, scale ]
			}
		
			thumb = img.thumbnail( scale )
			thumb.write( thumbnail )
		end
		
		path = thumbnail.relative_path_from( srcfile.dirname )
		return path, thumb.rows, thumb.columns
	end

end
