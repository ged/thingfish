
# Quickstart

To fire up the bare-bones server so you can start playin' around:

	$ rake install_dependencies
	$ ./run

The run script sets up the daemon to load its configuration from the 'etc/thingfish.conf' file,
which by default starts ThingFish in the foreground, and stores all uploaded data in memory.

After starting it, you should be able to point your browser at:

	http://localhost:3474/

and see the server's toplevel (completely optional) web interface. 

## Further Exploration

For more information about customizing and running your server, please see the included
documentation.

You can generate the manual and the API documentation (if you have the hoe-manualgen rubygem installed) by running:

	$ rake manual

These docs are now available for your viewing pleasure at:

	http://localhost:3474/manual/
	http://localhost:3474/api/
