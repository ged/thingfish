# Thingfish

home
: https://thing.fish

code
: https://hg.sr.ht/~ged/thingfish

docs
: https://thing.fish/docs/


## Description

Thingfish is a extensible, web-based digital asset manager. It can be used to
store chunks of data on the network in an application-independent way, link the
chunks together with metadata, and then search for the chunk you need later and
fetch it, all through a REST API.


## Requirements

Thingfish is written in ruby, and is tested using [version 2.7](http://www.ruby-lang.org/en/downloads/). Other versions may work,
but are not tested.


## Installation

You can install Thingfish via Rubygems:

    $ gem install thingfish

This will install the basic server and its dependencies. Additional functionality is available via separate gems in the following namespaces:

`thingfish-metastore-*`
: Storage backends for resource metadata

`thingfish-filestore-*`
: Storage backends for resources themselves

`thingfish-processor-*`
: Filters and extractors for resources


## Contributing

You can check out the current development source
{with Mercurial}[http://bitbucket.org/ged/thingfish], or
if you prefer Git, via the project's
{Github mirror}[https://github.com/ged/thingfish].

After checking out the source, run:

	$ rake newb

This task will install any missing dependencies, run the tests/specs, and 
generate the API documentation.

You can submit bug reports, suggestions, and read more about future plans at
{the project page}[http://bitbucket.org/ged/thingfish].


## Authors

* Michael Granger <ged@FaerieMUD.org>
* Mahlon E. Smith <mahlon@martini.nu>


## Contributors

* Jeremiah Jordan <phaedrus@perlreason.com>
* Ben Bleything <ben@bleything.net>
* Jeff Davis <jeff-thingfish@j-davis.com>


## License

Copyright (c) 2007-2020, Michael Granger and Mahlon E. Smith
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the author/s, nor the names of the project's
  contributors may be used to endorse or promote products derived from this
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


