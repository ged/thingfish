
$(document).ready(function() {

	$("a.meta").click( viewMetaData );
	$("a.delete").click( deleteResource );
});

function deleteResource()
{
	var uuid   = this.id.split(':')[1]
	var uri    = '/' + uuid;

	var doIt = confirm('Are you sure you want to delete this resource? (' + uuid + ')');
	if ( ! doIt ) return false;			

	$.ajax({
		url:     uri,
		type:    'DELETE',
		success: function(response){
			alert( response );

			// refresh search results
			window.location.reload();
		}
	});
}

function viewMetaData()
{
	var uuid   = this.id.split(':')[1]
	var uri    = metadata_uri + '/' + uuid;
	var button = this;

	metahtml = '<tr id="metarow" style="display: none;"><td colspan="2">' +
			   '<table id="metainfo"></table>' +
			   '</td></tr>';

	$.ajax({
		url:         uri,
		type:        'GET',
		contentType: 'application/json',
		dataType:    'json',
		processData: true,
		beforeSend:  function(xhr){ xhr.setRequestHeader('Accept','application/json') },
		error:       function(xhr, status, error) { window.location = uri; },
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
					'<th>' + key  + '</th>' +
					'<td>' + link + '</td>' +
					'</tr>'
				);
			});

			$('#metarow').show();
		}
	});

	return false;
}

