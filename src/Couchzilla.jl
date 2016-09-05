__precompile__()

"""
The CouchDB API.

## Types

* `Client`
* `Database`
* `HTTPException`
* `QueryResult`
* `Selector`

## CouchDB instance API

* `createdb()`
* `connectdb()`
* `dbinfo()`
* `listdbs()`
* `deletedb()`

## CouchDB CRUD  

* `createdoc()`
* `readdoc()`
* `updatedoc()`
* `deletedoc()`

## Attachments

* `put_attachment()`
* `get_attachment()`
* `delete_attachment()`

## Mango/Cloudant Query

* `mango_index()`
* `mango_query()`
* `paged_mango_query()`
* `listindexes()`
* `mango_deleteindex()`
* `and()`
* `or()`
* `nor()`
* `not()`
* `@q_str()`

## Views

* `view_index()`
* `view_query()`
* `alldocs()`

## Replication

* `changes()`
* `changes_streaming()`
* `revs_diff()`
* `bulk_get()`

## Geospatial

* `geo_index()`
* `geo_indexinfo()`
* `geo_query()`

## utils

* `retry_settings()`
"""
module Couchzilla

using Requests
using URIParser
using JSON

import Requests: get, post, put, delete, requestfor, headers

include("utils.jl")
include("client.jl")
include("database.jl")
include("selector.jl")
include("mango.jl")
include("attachments.jl")
include("replication.jl")
include("views.jl")
include("tasks.jl")
include("geospatial.jl")

export Client, Database, HTTPException 
export createdb, connectdb, dbinfo, listdbs, deletedb
export updatedoc, deletedoc, createdoc, readdoc
export put_attachment, get_attachment, delete_attachment
export QueryResult, Selector, @q_str, and, or, nor, not
export mango_query, mango_index, listindexes, mango_deleteindex, paged_mango_query
export view_index, view_query, alldocs
export revs_diff, changes, changes_streaming, bulk_get
export geo_index, geo_indexinfo, geo_query
export retry_settings, retry_settings!

end # module