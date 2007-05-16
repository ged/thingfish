#!/usr/bin/ruby

# $ svn info 
# Path: .
# URL: svn+ssh://roke/repo/laika-oss/thingfish/trunk
# Repository Root: svn+ssh://roke/repo/laika-oss
# Repository UUID: 5dcd19c2-c896-db11-984f-0013725a254b
# Revision: 187
# Node Kind: directory
# Schedule: normal
# Last Changed Author: mgranger
# Last Changed Rev: 186
# Last Changed Date: 2007-05-11 18:29:56 -0700 (Fri, 11 May 2007)

### Find the revision of the +target+ file or directory and return it as an
### integer.
def extract_svn_rev( target )
	output = %x{svn info #{target}}
	if output =~ /Revision: (\d+)/
		return Integer( $1 )
	else
		return nil
	end
end

