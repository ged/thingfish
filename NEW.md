Thingfish API -- Desired
=================================================

# introspection
OPTIONS /v1

# Search (via params), fetch all assets
GET /v1

# fetch an asset body
GET /v1/«uuid» *

# create a new asset
POST /v1 *

# update (replace) an asset body
PUT /v1/«uuid» *

# remove an asset and its metadata
DELETE /v1/«uuid»

# retrieve all metadata associated with an asset
GET /v1/«uuid»/metadata

# retrieve values for an asset's metadata key
GET /v1/«uuid»/metadata/«key»

# append additional metadata for an asset
POST /v1/«uuid»/metadata

# add a value for an asset's specific metadata key
POST /v1/«uuid»/metadata/«key»

# replace metadata for an asset
PUT /v1/«uuid»/metadata

# update an asset's specific metadata key
PUT /v1/«uuid»/metadata/«key»

# remove all user metadata for an asset
DELETE /v1/«uuid»/metadata

# delete an asset's specific metadata key
DELETE /v1/«uuid»/metadata/«key»


