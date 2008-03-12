# 
# Presentation Rake tasks for ThingFish
# $Id$
# 


### Task: rdoc
task :presentations do
	outputdir = DOCSDIR + 'presentations'
	targetdir = STATICWWWDIR + 'api'

	rmtree( targetdir )
	cp_r( outputdir, targetdir, :verbose => true )
end
task :clobber_rdoc do
	rmtree( STATICWWWDIR + 'api', :verbose => true )
end

