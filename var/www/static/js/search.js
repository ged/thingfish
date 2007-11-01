
$(document).ready(function() {

	$("a.meta").click( viewMetaData );
});


function viewMetaData()
{
	var uuid   = this.id.split(':')[1]
	var uri    = metadata_uri + '/' + uuid;
	var button = this;

	metahtml = '<tr id="metarow"><td colspan="2">' +
			   '<table id="metainfo"></table>' +
			   '</td></tr>';

	$.ajax({
		url:         uri,
		type:        'GET',
		contentType: 'application/json',
		dataType:    'json',
		processData: true,
		beforeSend:  function(xhr){ xhr.setRequestHeader('Accept','application/json') },
		success:     function(data){

			// remove any existing metadata tables
			$("#metarow").remove();

			// insert a new table row with the metadata node within it.
			$(button).parents('tr').eq(0).after( metahtml );

			// sort the metadata keys
			sorted = [];
			$.each( data, function( k, v ){ sorted.push(k) });
			sorted = sorted.sort();

			// iterate over the sorted keys, add them to the metainfo table.
			metainfo = $('#metainfo');
			$.each( sorted, function(i) {

				var key   = sorted[i];
				var value = data[ sorted[i] ];

				link = '<a href="' + '/search?' +
						escape( key ) + '=' + escape( value ) + '">' +
						value + '</a>';

				metainfo.append(
					'<tr>' +
					'<td>' + key  + '</td>' +
					'<td>' + link + '</td>' +
					'</tr>'
				);
			});

			$('#metarow').show();
		}
	});

	return false;
}

