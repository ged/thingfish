#!/usr/bin/ruby
# coding: utf-8

require 'pathname'
require 'tmpdir'
require 'yaml'
require 'thingfish'
require 'uuidtools'


# A collection of constants for convenience and readability
#
# == Synopsis
#
#   require 'thingfish/constants'
#
#   response = HTTP::BAD_REQUEST
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
module ThingFish::Constants

	# The subversion ID
	SVNId = %q$Id$

	# The SVN revision number
	SVNRev = %q$Rev$

	# The default listening ip or hostname
	DEFAULT_BIND_IP = '0.0.0.0'

	# The default host to connect to as a client
	DEFAULT_HOST = 'localhost'

	# The default port to listen on
	DEFAULT_PORT = 3474

	# The buffer chunker size
	DEFAULT_BUFSIZE = 2 ** 14

	# The default directory ThingFish will use to store data files, spool files,
	# its pid, and anything else. (unless configured otherwise)
	DEFAULT_DATADIR = Dir.tmpdir + '/thingfish'

	# The default location of upload temporary files
	DEFAULT_SPOOLDIR = 'spool'

	# The default location of Ruby-Prof output
	DEFAULT_PROFILEDIR = 'profiles'

	# Query argument that enables profiling for the current request
	PROFILING_ARG = '_profile'


	### Constants for HTTP headers

	# The version of the server
	SERVER_VERSION = ThingFish::VERSION

	# The version + the name of the server
	SERVER_SOFTWARE = "ThingFish/#{SERVER_VERSION}"

	# Version and name of the server + subversion rev
	SERVER_SOFTWARE_DETAILS = "#{SERVER_SOFTWARE} (#{SVNRev})"

	# Suck in a mapping of default mime types by file extension from the data
	# section of this file
	if File.instance_methods.include?( :external_encoding )
		MIMETYPE_MAP = YAML.load( File.read(__FILE__, :encoding => 'utf-8').split(/^__END__/, 2).last )
	else
		MIMETYPE_MAP = YAML.load( File.read(__FILE__).split(/^__END__/, 2).last )
	end

	# A MIME type string that indicates an entity body is XHTML
	XHTML_MIMETYPE = 'application/xhtml+xml'
	HTML_MIMETYPE = 'text/html'
	CONFIGURED_HTML_MIMETYPE = HTML_MIMETYPE

	# A MIME type that indicates an entity body is a Ruby data structure.
	RUBY_MIMETYPE = 'x-ruby/data'

	# A MIME type that indicates an entity body contains a marshalled Ruby data structure.
	RUBY_MARSHALLED_MIMETYPE = 'x-ruby/marshalled-data'

	# Pattern to match a valid multipart form upload 'Content-Type' header
	MULTIPART_MIMETYPE_PATTERN = %r{(multipart/form-data).*boundary="?([^\";,]+)"?}

	# The default content type
	DEFAULT_CONTENT_TYPE = 'application/octet-stream'

	# The format used to create the HTTP response's status line
	STATUS_LINE_FORMAT = "HTTP/1.1 %d %s\r\n".freeze

	# The format used to generate HTTP headers
	HEADER_FORMAT      = "%s: %s\r\n".freeze


	# The default search result size if none is specified
	DEFAULT_LIMIT = 100


	# HTTP status and result constants
	module HTTP
		SWITCHING_PROTOCOLS 		  = 101
		PROCESSING          		  = 102

		OK                			  = 200
		CREATED           			  = 201
		ACCEPTED          			  = 202
		NON_AUTHORITATIVE 			  = 203
		NO_CONTENT        			  = 204
		RESET_CONTENT     			  = 205
		PARTIAL_CONTENT   			  = 206
		MULTI_STATUS      			  = 207

		MULTIPLE_CHOICES   			  = 300
		MOVED_PERMANENTLY  			  = 301
		MOVED              			  = 301
		MOVED_TEMPORARILY  			  = 302
		REDIRECT           			  = 302
		SEE_OTHER          			  = 303
		NOT_MODIFIED       			  = 304
		USE_PROXY          			  = 305
		TEMPORARY_REDIRECT 			  = 307

		BAD_REQUEST                   = 400
		AUTH_REQUIRED                 = 401
		UNAUTHORIZED                  = 401
		PAYMENT_REQUIRED              = 402
		FORBIDDEN                     = 403
		NOT_FOUND                     = 404
		METHOD_NOT_ALLOWED            = 405
		NOT_ACCEPTABLE                = 406
		PROXY_AUTHENTICATION_REQUIRED = 407
		REQUEST_TIME_OUT              = 408
		CONFLICT                      = 409
		GONE                          = 410
		LENGTH_REQUIRED               = 411
		PRECONDITION_FAILED           = 412
		REQUEST_ENTITY_TOO_LARGE      = 413
		REQUEST_URI_TOO_LARGE         = 414
		UNSUPPORTED_MEDIA_TYPE        = 415
		RANGE_NOT_SATISFIABLE         = 416
		EXPECTATION_FAILED            = 417
		UNPROCESSABLE_ENTITY          = 422
		LOCKED                        = 423
		FAILED_DEPENDENCY             = 424

		SERVER_ERROR          		  = 500
		NOT_IMPLEMENTED       		  = 501
		BAD_GATEWAY           		  = 502
		SERVICE_UNAVAILABLE   		  = 503
		GATEWAY_TIME_OUT      		  = 504
		VERSION_NOT_SUPPORTED 		  = 505
		VARIANT_ALSO_VARIES   		  = 506
		INSUFFICIENT_STORAGE  		  = 507
		NOT_EXTENDED          		  = 510

		# Stolen from Apache 2.2.6's modules/http/http_protocol.c
		STATUS_NAME = {
		    100 => "Continue",
		    101 => "Switching Protocols",
		    102 => "Processing",
		    200 => "OK",
		    201 => "Created",
		    202 => "Accepted",
		    203 => "Non-Authoritative Information",
		    204 => "No Content",
		    205 => "Reset Content",
		    206 => "Partial Content",
		    207 => "Multi-Status",
		    300 => "Multiple Choices",
		    301 => "Moved Permanently",
		    302 => "Found",
		    303 => "See Other",
		    304 => "Not Modified",
		    305 => "Use Proxy",
		    306 => "Undefined HTTP Status",
		    307 => "Temporary Redirect",
		    400 => "Bad Request",
		    401 => "Authorization Required",
		    402 => "Payment Required",
		    403 => "Forbidden",
		    404 => "Not Found",
		    405 => "Method Not Allowed",
		    406 => "Not Acceptable",
		    407 => "Proxy Authentication Required",
		    408 => "Request Time-out",
		    409 => "Conflict",
		    410 => "Gone",
		    411 => "Length Required",
		    412 => "Precondition Failed",
		    413 => "Request Entity Too Large",
		    414 => "Request-URI Too Large",
		    415 => "Unsupported Media Type",
		    416 => "Requested Range Not Satisfiable",
		    417 => "Expectation Failed",
		    418 => "Undefined HTTP Status",
		    419 => "Undefined HTTP Status",
		    420 => "Undefined HTTP Status",
		    421 => "Undefined HTTP Status",
		    406 => "Not Acceptable",
		    407 => "Proxy Authentication Required",
		    408 => "Request Time-out",
		    409 => "Conflict",
		    410 => "Gone",
		    411 => "Length Required",
		    412 => "Precondition Failed",
		    413 => "Request Entity Too Large",
		    414 => "Request-URI Too Large",
		    415 => "Unsupported Media Type",
		    416 => "Requested Range Not Satisfiable",
		    417 => "Expectation Failed",
		    418 => "Undefined HTTP Status",
		    419 => "Undefined HTTP Status",
		    420 => "Undefined HTTP Status",
		    421 => "Undefined HTTP Status",
		    422 => "Unprocessable Entity",
		    423 => "Locked",
		    424 => "Failed Dependency",
		    425 => "No code",
		    426 => "Upgrade Required",
		    500 => "Internal Server Error",
		    501 => "Method Not Implemented",
		    502 => "Bad Gateway",
		    503 => "Service Temporarily Unavailable",
		    504 => "Gateway Time-out",
		    505 => "HTTP Version Not Supported",
		    506 => "Variant Also Negotiates",
		    507 => "Insufficient Storage",
		    508 => "Undefined HTTP Status",
		    509 => "Undefined HTTP Status",
		    510 => "Not Extended"
		}


		# Methods which aren't allowed to have an entity-body
		SHALLOW_METHODS = [ :GET, :HEAD, :DELETE ]
	end


	module Patterns
		# Patterns for matching UUIDs and parts of UUIDs
		HEX12 = /[[:xdigit:]]{12}/
		HEX8  = /[[:xdigit:]]{8}/
		HEX4  = /[[:xdigit:]]{4}/
		HEX2  = /[[:xdigit:]]{2}/

		# Pattern for matching a plain UUID string
		UUID_REGEXP = /#{HEX8}-#{HEX4}-#{HEX4}-#{HEX4}-#{HEX12}/

		# Pattern to match UUIDs more efficiently than uuidtools
		UUID_PATTERN = /^(#{HEX8})-(#{HEX4})-(#{HEX4})-(#{HEX2})(#{HEX2})-(#{HEX12})$/

		# Pattern for matching UUID URNs, capturing the UUID string
		UUID_URN = /urn:uuid:(#{UUID_REGEXP})/i

		# Pattern that matches requests to /«a uuid»; captures the UUID string
		UUID_URL = %r{^(#{UUID_REGEXP})$}

		# Pattern that matches a valid property name
		PROPERTY_NAME_REGEXP = %r{\w[\w:\-]+}

		# Pattern that matches requests to /«a property name»; captures the property name string
		PROPERTY_NAME_URL = %r{^(#{PROPERTY_NAME_REGEXP})$}

		# Pattern that matches requests to /«a uuid»/«a property name»; captures the uuid
		# and the property name string
		UUID_PROPERTY_URL = %r{^(#{UUID_REGEXP})/(#{PROPERTY_NAME_REGEXP})$}

		# Network IO constants
		CRLF        = "\r\n"
		EOL         = CRLF
		BLANK_LINE  = CRLF + CRLF

		# Network IO patterns
		CRLF_REGEXP        = /\r?\n/
		BLANK_LINE_REGEXP  = /#{CRLF_REGEXP}#{CRLF_REGEXP}/
	end

end # module ThingFish::Constants


__END__
---
.a: application/octet-stream
.abc: text/vnd.abc
.acgi: text/html
.afl: video/animaflex
.ai: application/postscript
.aif: audio/aiff
.aifc: audio/aiff
.aiff: audio/aiff
.aip: text/x-audiosoft-intra
.ani: application/x-navi-animation
.aps: application/mime
.arc: application/octet-stream
.arj: application/octet-stream
.art: image/x-jg
.asf: video/x-ms-asf
.asm: text/x-asm
.asp: text/asp
.asr: video/x-ms-asf
.asx: video/x-ms-asf
.atom: application/xml+atom
.au: audio/basic
.au: audio/x-au
.avi: video/avi
.avs: video/avs-video
.axs: application/olescript
.bas: text/plain
.bcpio: application/x-bcpio
.bin: application/octet-stream
.bm: image/bmp
.bmp: image/bmp
.boo: application/book
.book: application/book
.boz: application/x-bzip2
.bsh: application/x-bsh
.bz2: application/x-bzip2
.bz: application/x-bzip
.c: text/plain
.cat: application/octet-stream
.cc: text/plain
.ccad: application/clariscad
.cco: application/x-cocoa
.cdf: application/cdf
.cer: application/x-x509-ca-cert
.cha: application/x-chat
.chat: application/x-chat
.class: application/java
.class: application/octet-stream
.clp: application/x-msclip
.cmx: image/x-cmx
.cod: image/cis-cod
.com: application/octet-stream
.com: text/plain
.conf: text/plain
.cpio: application/x-cpio
.cpp: text/x-c
.cpt: application/x-cpt
.crd: application/x-mscardfile
.crl: application/pkcs-crl
.crl: application/pkix-crl
.crt: application/x-x509-ca-cert
.csh: application/x-csh
.csh: text/x-script.csh
.css: text/css
.cxx: text/plain
.dcr: application/x-director
.deb: application/octet-stream
.deepv: application/x-deepv
.def: text/plain
.der: application/x-x509-ca-cert
.dhh: application/david-heinemeier-hansson
.dif: video/x-dv
.dir: application/x-director
.dl: video/dl
.dll: application/octet-stream
.dmg: application/octet-stream
.dms: application/octet-stream
.doc: application/msword
.dp: application/commonground
.drw: application/drafting
.dump: application/octet-stream
.dv: video/x-dv
.dvi: application/x-dvi
.dwg: application/acad
.dwg: image/x-dwg
.dxf: application/dxf
.dxf: image/x-dwg
.dxr: application/x-director
.ear: application/java-archive
.el: text/x-script.elisp
.elc: application/x-bytecode.elisp (compiled elisp)
.elc: application/x-elc
.env: application/x-envoy
.eot: application/octet-stream
.eps: application/postscript
.es: application/x-esrehber
.etx: text/x-setext
.evy: application/envoy
.evy: application/x-envoy
.exe: application/octet-stream
.exr: image/x-exr
.f77: text/x-fortran
.f90: text/plain
.f90: text/x-fortran
.f: text/x-fortran
.fdf: application/vnd.fdf
.fif: application/fractals
.fif: image/fif
.fli: video/fli
.fli: video/x-fli
.flo: image/florian
.flr: x-world/x-vrml
.flv: video/x-flv
.flx: text/vnd.fmi.flexstor
.fmf: video/x-atomic3d-feature
.for: text/plain
.for: text/x-fortran
.fpx: image/vnd.fpx
.fpx: image/vnd.net-fpx
.frl: application/freeloader
.funk: audio/make
.g3: image/g3fax
.g: text/plain
.gif: image/gif
.gl: video/gl
.gl: video/x-gl
.gsd: audio/x-gsm
.gsm: audio/x-gsm
.gsp: application/x-gsp
.gss: application/x-gss
.gtar: application/x-gtar
.gz: application/x-compressed
.gzip: application/x-gzip
.h: text/plain
.hdf: application/x-hdf
.help: application/x-helpfile
.hgl: application/vnd.hp-hpgl
.hh: text/plain
.hlb: text/x-script
.hlp: application/hlp
.hpg: application/vnd.hp-hpgl
.hpgl: application/vnd.hp-hpgl
.hqx: application/binhex
.hta: application/hta
.htc: text/x-component
.htm: text/html
.html: text/html
.htmls: text/html
.htt: text/webviewhtml
.htx: text/html
.ico: image/x-icon
.idc: text/plain
.ief: image/ief
.iefs: image/ief
.iges: application/iges
.igs: application/iges
.iii: application/x-iphone
.ima: application/x-ima
.imap: application/x-httpd-imap
.img: application/octet-stream
.inf: application/inf
.ins: application/x-internet-signup
.ins: application/x-internett-signup
.ip: application/x-ip2
.iso: application/octet-stream
.isp: application/x-internet-signup
.isu: video/x-isvideo
.it: audio/it
.iv: application/x-inventor
.ivr: i-world/i-vrml
.ivy: application/x-livescreen
.jam: audio/x-jam
.jar: application/java-archive
.jardiff: application/x-java-archive-diff
.jav: text/plain
.jav: text/x-java-source
.java: text/plain
.java: text/x-java-source
.jcm: application/x-java-commerce
.jfif-tbnl: image/jpeg
.jfif: image/jpeg
.jfif: image/pipeg
.jfif: image/pjpeg
.jng: image/x-jng
.jnlp: application/x-java-jnlp-file
.jpe: image/jpeg
.jpeg: image/jpeg
.jpg: image/jpeg
.jps: image/x-jps
.js: application/x-javascript
.js: text/javascript
.jut: image/jutvision
.kar: audio/midi
.kar: music/x-karaoke
.ksh: application/x-ksh
.ksh: text/x-script.ksh
.la: audio/nspaudio
.la: audio/x-nspaudio
.lam: audio/x-liveaudio
.latex: application/x-latex
.lha: application/lha
.lha: application/octet-stream
.lha: application/x-lha
.lhx: application/octet-stream
.list: text/plain
.lma: audio/nspaudio
.lma: audio/x-nspaudio
.log: text/plain
.lsf: video/x-la-asf
.lsp: application/x-lisp
.lsp: text/x-script.lisp
.lst: text/plain
.lsx: text/x-la-asf
.lsx: video/x-la-asf
.ltx: application/x-latex
.lzh: application/octet-stream
.lzh: application/x-lzh
.lzx: application/lzx
.lzx: application/octet-stream
.lzx: application/x-lzx
.m13: application/x-msmediaview
.m14: application/x-msmediaview
.m1v: video/mpeg
.m2a: audio/mpeg
.m2v: video/mpeg
.m3u: audio/x-mpegurl
.m: text/x-m
.man: application/x-troff-man
.map: application/x-navimap
.mar: text/plain
.mbd: application/mbedlet
.mc: application/x-magic-cap-package-1.0
.mcd: application/mcad
.mcd: application/x-mathcad
.mcf: image/vasa
.mcf: text/mcf
.mcp: application/netmc
.mdb: application/x-msaccess
.me: application/x-troff-me
.mht: message/rfc822
.mhtml: message/rfc822
.mid: audio/mid
.mid: audio/midi
.mid: audio/x-mid
.mid: audio/x-midi
.midi: audio/midi
.midi: audio/x-mid
.midi: audio/x-midi
.mif: application/x-frame
.mif: application/x-mif
.mime: message/rfc822
.mime: www/mime
.mjf: audio/x-vnd.audioexplosion.mjuicemediafile
.mjpg: video/x-motion-jpeg
.mm: application/base64
.mm: application/x-meme
.mme: application/base64
.mml: text/mathml
.mng: video/x-mng
.mod: audio/mod
.moov: video/quicktime
.mov: video/quicktime
.movie: video/x-sgi-movie
.mp2: audio/mpeg
.mp3: audio/mpeg
.mpa: audio/mpeg
.mpc: application/x-project
.mpe: video/mpeg
.mpeg: video/mpeg
.mpg: video/mpeg
.mpga: audio/mpeg
.mpp: application/vnd.ms-project
.mpt: application/x-project
.mpv2: video/mpeg
.mpv: application/x-project
.mpx: application/x-project
.mrc: application/marc
.ms: application/x-troff-ms
.msi: application/octet-stream
.msm: application/octet-stream
.msp: application/octet-stream
.mv: video/x-sgi-movie
.mvb: application/x-msmediaview
.my: audio/make
.mzz: application/x-vnd.audioexplosion.mzz
.nap: image/naplps
.naplps: image/naplps
.nc: application/x-netcdf
.ncm: application/vnd.nokia.configuration-message
.nif: image/x-niff
.niff: image/x-niff
.nix: application/x-mix-transfer
.nsc: application/x-conference
.nvd: application/x-navidoc
.nws: message/rfc822
.o: application/octet-stream
.oda: application/oda
.omc: application/x-omc
.omcd: application/x-omcdatamaker
.omcr: application/x-omcregerator
.p10: application/pkcs10
.p10: application/x-pkcs10
.p12: application/pkcs-12
.p12: application/x-pkcs12
.p7a: application/x-pkcs7-signature
.p7b: application/x-pkcs7-certificates
.p7c: application/pkcs7-mime
.p7c: application/x-pkcs7-mime
.p7m: application/pkcs7-mime
.p7m: application/x-pkcs7-mime
.p7r: application/x-pkcs7-certreqresp
.p7s: application/pkcs7-signature
.p7s: application/x-pkcs7-signature
.p: text/x-pascal
.part: application/pro_eng
.pas: text/pascal
.pbm: image/x-portable-bitmap
.pcl: application/vnd.hp-pcl
.pcl: application/x-pcl
.pct: image/x-pict
.pcx: image/x-pcx
.pdb: application/x-pilot
.pdf: application/pdf
.pem: application/x-x509-ca-cert
.pfunk: audio/make
.pfunk: audio/make.my.funk
.pfx: application/x-pkcs12
.pgm: image/x-portable-graymap
.pgm: image/x-portable-greymap
.pic: image/pict
.pict: image/pict
.pkg: application/x-newton-compatible-pkg
.pko: application/vnd.ms-pki.pko
.pko: application/ynd.ms-pkipko
.pl: application/x-perl
.pl: text/plain
.pl: text/x-script.perl
.plx: application/x-pixclscript
.pm4: application/x-pagemaker
.pm5: application/x-pagemaker
.pm: application/x-perl
.pm: image/x-xpixmap
.pm: text/x-script.perl-module
.pma: application/x-perfmon
.pmc: application/x-perfmon
.pml: application/x-perfmon
.pmr: application/x-perfmon
.pmw: application/x-perfmon
.png: image/png
.pnm: application/x-portable-anymap
.pnm: image/x-portable-anymap
.pot,: application/vnd.ms-powerpoint
.pot: application/mspowerpoint
.pot: application/vnd.ms-powerpoint
.pov: model/x-pov
.ppa: application/vnd.ms-powerpoint
.ppm: image/x-portable-pixmap
.pps: application/mspowerpoint
.ppt: application/mspowerpoint
.ppz: application/mspowerpoint
.prc: application/x-pilot
.pre: application/x-freelance
.prf: application/pics-rules
.prt: application/pro_eng
.ps: application/postscript
.psd: application/octet-stream
.pub: application/x-mspublisher
.pvu: paleovu/x-pv
.pwz: application/vnd.ms-powerpoint
.py: text/x-script.phyton
.pyc: applicaiton/x-bytecode.python
.qcp: audio/vnd.qcelp
.qd3: x-world/x-3dmf
.qd3d: x-world/x-3dmf
.qif: image/x-quicktime
.qt: video/quicktime
.qtc: video/x-qtc
.qti: image/x-quicktime
.qtif: image/x-quicktime
.ra: audio/x-pn-realaudio
.ra: audio/x-pn-realaudio-plugin
.ra: audio/x-realaudio
.ram: audio/x-pn-realaudio
.rar: application/x-rar-compressed
.ras: application/x-cmu-raster
.ras: image/cmu-raster
.ras: image/x-cmu-raster
.rast: image/cmu-raster
.rexx: text/x-script.rexx
.rf: image/vnd.rn-realflash
.rgb: image/x-rgb
.rm: application/vnd.rn-realmedia
.rm: audio/x-pn-realaudio
.rmi: audio/mid
.rmm: audio/x-pn-realaudio
.rmp: audio/x-pn-realaudio
.rmp: audio/x-pn-realaudio-plugin
.rng: application/ringing-tones
.rng: application/vnd.nokia.ringing-tone
.rnx: application/vnd.rn-realplayer
.roff: application/x-troff
.rp: image/vnd.rn-realpix
.rpm: application/x-redhat-package-manager
.rpm: audio/x-pn-realaudio-plugin
.rss: text/xml
.rt: text/richtext
.rt: text/vnd.rn-realtext
.rtf: application/rtf
.rtf: application/x-rtf
.rtf: text/richtext
.rtx: application/rtf
.rtx: text/richtext
.run: application/x-makeself
.rv: video/vnd.rn-realvideo
.s3m: audio/s3m
.s: text/x-asm
.saveme: application/octet-stream
.sbk: application/x-tbook
.scd: application/x-msschedule
.scm: application/x-lotusscreencam
.scm: text/x-script.guile
.scm: text/x-script.scheme
.scm: video/x-scm
.sct: text/scriptlet
.sdml: text/plain
.sdp: application/sdp
.sdp: application/x-sdp
.sdr: application/sounder
.sea: application/sea
.sea: application/x-sea
.set: application/set
.setpay: application/set-payment-initiation
.setreg: application/set-registration-initiation
.sgm: text/sgml
.sgm: text/x-sgml
.sgml: text/sgml
.sgml: text/x-sgml
.sh: application/x-bsh
.sh: application/x-sh
.sh: application/x-shar
.sh: text/x-script.sh
.shar: application/x-bsh
.shar: application/x-shar
.shtml: text/html
.shtml: text/x-server-parsed-html
.sid: audio/x-psid
.sit: application/x-sit
.sit: application/x-stuffit
.skd: application/x-koan
.skm: application/x-koan
.skp: application/x-koan
.skt: application/x-koan
.sl: application/x-seelogo
.smi: application/smil
.smil: application/smil
.snd: audio/basic
.snd: audio/x-adpcm
.sol: application/solids
.spc: application/x-pkcs7-certificates
.spc: text/x-speech
.spl: application/futuresplash
.spr: application/x-sprite
.sprite: application/x-sprite
.src: application/x-wais-source
.ssi: text/x-server-parsed-html
.ssm: application/streamingmedia
.sst: application/vnd.ms-pki.certstore
.sst: application/vnd.ms-pkicertstore
.step: application/step
.stl: application/sla
.stl: application/vnd.ms-pki.stl
.stl: application/vnd.ms-pkistl
.stl: application/x-navistyle
.stm: text/html
.stp: application/step
.sv4cpio: application/x-sv4cpio
.sv4crc: application/x-sv4crc
.svf: image/vnd.dwg
.svf: image/x-dwg
.svg: image/svg+xml
.svr: application/x-world
.svr: x-world/x-svr
.swf: application/x-shockwave-flash
.t: application/x-troff
.talk: text/x-speech
.tar: application/x-tar
.tbk: application/toolbook
.tbk: application/x-tbook
.tcl: application/x-tcl
.tcl: text/x-script.tcl
.tcsh: text/x-script.tcsh
.tex: application/x-tex
.texi: application/x-texinfo
.texinfo: application/x-texinfo
.text: application/plain
.text: text/plain
.tgz: application/gnutar
.tgz: application/x-compressed
.tif: image/tiff
.tiff: image/tiff
.tk: application/x-tcl
.tr: application/x-troff
.trm: application/x-msterminal
.tsi: audio/tsp-audio
.tsp: application/dsptype
.tsp: audio/tsplayer
.tsv: text/tab-separated-values
.turbot: image/florian
.txt: text/plain
.uil: text/x-uil
.uls: text/iuls
.uni: text/uri-list
.unis: text/uri-list
.unv: application/i-deas
.uri: text/uri-list
.uris: text/uri-list
.ustar: application/x-ustar
.ustar: multipart/x-ustar
.uu: application/octet-stream
.uu: text/x-uuencode
.uue: text/x-uuencode
.vcd: application/x-cdlink
.vcf: text/x-vcard
.vcs: text/x-vcalendar
.vda: application/vda
.vdo: video/vdo
.vew: application/groupwise
.viv: video/vivo
.viv: video/vnd.vivo
.vivo: video/vivo
.vivo: video/vnd.vivo
.vmd: application/vocaltec-media-desc
.vmf: application/vocaltec-media-file
.voc: audio/voc
.voc: audio/x-voc
.vos: video/vosaic
.vox: audio/voxware
.vqe: audio/x-twinvq-plugin
.vqf: audio/x-twinvq
.vql: audio/x-twinvq-plugin
.vrml: application/x-vrml
.vrml: model/vrml
.vrml: x-world/x-vrml
.vrt: x-world/x-vrt
.vsd: application/x-visio
.vst: application/x-visio
.vsw: application/x-visio
.w60: application/wordperfect6.0
.w61: application/wordperfect6.1
.w6w: application/msword
.war: application/java-archive
.wav: audio/wav
.wav: audio/x-wav
.wb1: application/x-qpro
.wbmp: image/vnd.wap.wbmp
.wbmp: image/vnd.wap.wbmp
.wcm: application/vnd.ms-works
.wdb: application/vnd.ms-works
.web: application/vnd.xara
.wiz: application/msword
.wk1: application/x-123
.wks: application/vnd.ms-works
.wmf: application/x-msmetafile
.wmf: windows/metafile
.wml: text/vnd.wap.wml
.wmlc: application/vnd.wap.wmlc
.wmls: text/vnd.wap.wmlscript
.wmlsc: application/vnd.wap.wmlscriptc
.wmv: video/x-ms-wmv
.word: application/msword
.wp5: application/wordperfect
.wp6: application/wordperfect
.wp: application/wordperfect
.wpd: application/wordperfect
.wps: application/vnd.ms-works
.wq1: application/x-lotus
.wri: application/mswrite
.wrl: application/x-world
.wsc: text/scriplet
.wsrc: application/x-wais-source
.wtk: application/x-wintalk
.x-png: image/png
.xaf: x-world/x-vrml
.xbm: image/xbm
.xdr: video/x-amt-demorun
.xgz: xgl/drawing
.xhtml: application/xhtml+xml
.xif: image/vnd.xiff
.xl: application/excel
.xla: application/excel
.xlb: application/excel
.xlc: application/excel
.xld: application/excel
.xlk: application/excel
.xll: application/excel
.xlm: application/excel
.xls: application/excel
.xlt: application/excel
.xlv: application/excel
.xlw: application/excel
.xm: audio/xm
.xml: text/xml
.xmz: xgl/movie
.xof: x-world/x-vrml
.xpi: application/x-xpinstall
.xpix: application/x-vnd.ls-xpix
.xpm: image/x-xpixmap
.xpm: image/xpm
.xsr: video/x-amt-showrun
.xwd: image/x-xwd
.xwd: image/x-xwindowdump
.xyz: chemical/x-pdb
.z: application/x-compressed
.zip: application/zip
.zoo: application/octet-stream
.zsh: text/x-script.zsh
