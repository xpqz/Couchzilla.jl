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

* `createindex()`
* `query()`
* `listindexes()`
* `deleteindex()`
* `and()`
* `or()`
* `nor()`
* `not()`
* `@q_str()`
* `paged_query()`

## Views

* `make_view()`
* `query_view()`
* `alldocs()`

## Replication

* `changes()`
* `changes_streaming()`
* `revs_diff()`
* `bulk_get()`
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

export Client, Database, HTTPException, QueryResult, Selector, @q_str
export createdb, connectdb, dbinfo, listdbs, deletedb, createdoc, readdoc
export updatedoc, deletedoc, alldocs, query, paged_query, createindex
export and, or, nor, not, put_attachment, get_attachment, delete_attachment
export make_view, query_view, listindexes, deleteindex
export revs_diff, changes, changes_streaming, bulk_get
export geo_index, geo_index_info, geo_query

end # module