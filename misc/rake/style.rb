# 
# Style Fixup Rake Tasks for ThingFish
# 
# 
# 

### Coding style checks and fixes
namespace :style do
	
	BLANK_LINE = /^\s*$/
	GOOD_INDENT = /^(\t\s*)?\S/
	BAD_WHITESPACE = /[ \t\r]+$/

	TARGET_FILES = LIB_FILES +
		SPEC_FILES +
		PLUGIN_LIBS +
		PLUGIN_SPECFILES

	# A list of the files that have legitimate leading whitespace, etc.
	PROBLEM_FILES = [ SPECDIR + 'config_spec.rb' ]

	desc "Fix all style problems"
	task :default => [ :fix_indent, :check_for_extra_whitespace ]
	

	desc "Check source files for inconsistent indent and fix them"
	task :fix_indent do

		badfiles = Hash.new {|h,k| h[k] = [] }
		
		trace "Checking files for indentation"
		TARGET_FILES.each do |file|
			if PROBLEM_FILES.include?( file )
				trace "  skipping problem file #{file}..."
				next
			end
			
			trace "  #{file}"
			linecount = 0
			file.each_line do |line|
				linecount += 1
				
				# Skip blank lines
				next if line =~ BLANK_LINE
				
				# If there's a line with incorrect indent, note it and skip to the 
				# next file
				if line !~ GOOD_INDENT
					trace "    Bad line %d: %p" % [ linecount, line ]
					badfiles[file] << [ linecount, line ]
				end
			end
		end

		if badfiles.empty?
			log "No indentation problems found."
		else
			log "Found incorrect indent in #{badfiles.length} files:\n  "
			badfiles.each do |file, badlines|
				log "  #{file}:\n" +
					"    " + badlines.collect {|badline| "%5d: %p" % badline }.join( "\n    " )
			end
		end
	end


	desc "Strip unnecessary whitespace (trailing, indents on blank lines, etc.)"
	task :check_for_extra_whitespace do
		badfiles = Hash.new {|h,k| h[k] = [] }
		
		trace "Checking files for extra whitespace"
		TARGET_FILES.each do |file|
			if PROBLEM_FILES.include?( file )
				trace "  skipping problem file #{file}..."
				next
			end

			trace "  #{file}"
			linecount = 0
			file.each_line do |line|
				linecount += 1
				
				# If there's a line with incorrect whitespace, note it and skip to the 
				# next file
				if line =~ BAD_WHITESPACE
					trace "    Bad line %d: %p" % [ linecount, line ]
					badfiles[file] << [ linecount, line ]
				end
			end
		end

		if badfiles.empty?
			log "No whitespace problems found."
		else
			log "Found unnecessary whitespace in #{badfiles.length} files:\n  "
			badfiles.each do |file, badlines|
				log "  #{file}:\n" +
					"    " + badlines.collect {|badline| "%5d: %p" % badline }.join( "\n    " )
			end
		end
		
	end
end


desc "Check for style problems"
task :style => 'style:default'

