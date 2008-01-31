// 
// ThingFish Javascript Client Library
// $Id$
// 
// Authors:
//   * Michael Granger <mgranger@laika.com>
//   * Mahlon E. Smith <mahlon@laika.com>
// 
// 


/*
 * Tentative API:
 * 
 * <script type="text/javascript" charset="utf-8" src="/js/thingfish.js">
 * </script>
 * 
 * // Connect to the ThingFish server
 * client = new ThingFish( server );
 * 
 * 
 * // -- Storing
 * 
 * var resource;
 * 
 * // Create the entry then save it
 * resource = new ThingFish.Resource( "data" );
 * resource.format = 'image/x-dxf';
 * resource = client.store( resource );
 * 
 * // Set some more metadata (method style):    #TODO#
 * resource.metadata.owner = 'mahlon';
 * resource.metadata.description = "3D model used to test the new All Open Source pipeline";
 * // ...or hash style:
 * resource.metadata['keywords'] = "3d, model, mahlon";
 * resource.metadata['date_created'] = new Date();
 * 
 * // Now save the resource back to the server it was fetched from
 * resource.save();
 * 
 * // Discard changes in favor of server side data    #TODO#
 * resource.revert();
 * 
 * 
 * // -- Fetching
 * 
 * // Fetch a resource by UUID
 * var uuid = '7602813e-dc77-11db-837f-0017f2004c5e';
 * resource = client.fetch( uuid );
 * 
 * // Use the data
 * resource.data
 * 
 * // Fetch a GIF resource as a PNG if the server supports that transformation:  #TODO#
 * resource = client.fetch( uuid, {as: 'image/png'} );
 * 
 * // Fetch a TIFF resource as either a JPEG or a PNG, preferring the former:  #TODO#
 * resource = client.fetch( uuid, {as: 'image/jpeg, image/png;q=0.5'} );
 * 
 * // Check to see if a UUID is a valid resource
 * client.has( uuid ); // => true or false
 * 
 * 
 * // -- Searching
 * 
 * // ...or search for resources whose metadata match search criteria. Find
 * // all DXF objects owned by Mahlon:   #TODO#
 * uuids = client.find({ format: 'image/x-dxf', owner: 'mahlon' });
 * 
 * 
 */
