#!/bin/sh

plugin_libs=(plugins/*/lib)

libflags=''
for libdir in ${plugin_libs[*]}; do
	libflags="-I${libdir} $libflags"
done

exec ruby -Ilib $libflags bin/thingfishd -f etc/thingfish.conf $*

