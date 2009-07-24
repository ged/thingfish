/**
 * ThingFish Digital Asset Manager UI 
 * $Id$
 * 
 * Authors:
 *  * Michael Granger <mgranger@laika.com>
 * 
 * 
 */

const Templates = {
	preview_smallsize: null
};

const Services = {
	search: '/search'
};


/**
 * Extract the parts of the page that are for reuse as templates into the Templates 
 * object.
 */
function extract_templates() {
	Templates.preview_smallsize = $('#preview-box .small-preview').remove();
}


/**
 * Display the array of thumbnails.
 */
function display_thumbnails( thumbnails ) {
	console.debug( "Got thumbnails: %o", thumbnails );
	var container = $('#preview-box');
	var imgbase = window.location.href.replace( /#$/, '' );

	for ( i in thumbnails ) {
		var thumbnail = thumbnails[i];
		var tmpl      = Templates.preview_smallsize.clone();
		var imgurl    = imgbase + thumbnail['uuid'];
		var count     = 0;

		tmpl.find('.preview-frame img').attr( 'src', imgurl );
		tmpl.find('.preview-metadata td').each( function() {
			var field = $(this).html();
			console.debug( "  setting the %o field to %o", field, thumbnail[field] );

			if ( thumbnail[field] ) {
				count++;
				$(this).html( thumbnail[field] );
				if ( count % 2 ) {
					$(this).parent('tr').addClass( 'odd' );
				} else {
					$(this).parent('tr').addClass( 'even' );
				}
			} else {
				console.error( "  removing row for non-existant %s property", field );
				$(this).parent('tr').remove();
			}
		});
	}
}


/**
 * Show recent assets that have been added in the preview box, or show 'no assets' if 
 * there are none.
 */
function show_recent_additions() {
	var search_uri = Services.search + '?format=image/*;relation=thumbnail';
	$.getJSON( search_uri, display_thumbnails );
}



$(document).ready( function() {
	 extract_templates();
	show_recent_additions();
});

