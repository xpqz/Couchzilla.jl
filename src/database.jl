# Implementation of the CouchDB CRUD API.
#
# This follows the example set by PouchDB of implementing all write operations via the 
# CouchDB _bulk_docs end point, instead of the mess of a mixture of POST, PUT and DELETE. 
# The advantage of this is much simpler code paths.
#
# There are some side effects of this, notably that some parameters that the other end points 
# support isn't supported here.

"""
    immutable Database
      url
      name
      client

      Database(client::Client, name::AbstractString) =
        new(URI(client.url.scheme, client.url.host, client.url.port, "/\$name"), name, client)
    end

The Database immutable is a client connection tied to a specific remote DB. It is 
normally not created directly, but via a call to `connectdb()`, or `createdb()`. 

### Examples

    # Connect to existing DB. Does not verify it exists.
    db = connectdb(client; database="mydb")

    # Create a new db if it doesn't exist, otherwise connect 
    db, created = createdb(client; database="mydb")
"""
immutable Database
  url
  name
  client

  Database(client::Client, name::AbstractString) =
    new(URI(client.url.scheme, client.url.host, client.url.port, "/$name"), name, client)
end

"""
    result = bulkdocs(db::Database; data=[], options=Dict())

Raw _bulk_docs.

This is a function primarily intended for internal use, but can
be used directly to create, update or delete documents in bulk,
so as to save on the HTTP overhead.

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs)
"""
function bulkdocs(db::Database; data=[], options=Dict())
  post_url = endpoint(db.url, "_bulk_docs")
  relax(post, post_url; json=Dict("docs" => data), cookies=db.client.cookies, query=options)
end

"""
    result = createdoc(db::Database; body=Dict())

Create a new document.

Note that this is implemented via the `_bulk_docs` endpoint, rather 
than a `POST` to the `/{DB}`.

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs)
"""
function createdoc(db::Database, body=Dict())
  response = bulkdocs(db; data=[body])
  response[1]
end

"""
    result = createdoc(db::Database; data=[Dict()])

Bulk create a set of new documents via the CouchDB `_bulk_docs` endpoint.

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs)
"""
function createdoc(db::Database; data = Vector{Dict{Any, Any}}())
  if length(data) == 0
    error("No data given")
  end
  
  bulkdocs(db; data=data)
end

"""
    result = readdoc(db::Database, id::AbstractString; 
      rev               = "", 
      attachments       = false, 
      att_encoding_info = false,
      atts_since        = [],
      open_revs         = [],
      conflicts         = false,
      deleted_conflicts = false,
      latest            = false,
      meta              = false,
      revs              = false,
      revs_info         = false)

Fetch a document by `id`.

For a description of the parameters, see reference below. To use the `open_revs` parameter as `all`, use

    result = readdoc(db, id; open_revs=["all"])

[API reference](http://docs.couchdb.org/en/1.6.1/api/document/common.html#get--db-docid)
"""
function readdoc(db::Database, id::AbstractString; 
  rev               = "", 
  attachments       = false, 
  att_encoding_info = false,
  atts_since        = [],
  open_revs         = [],
  conflicts         = false,
  deleted_conflicts = false,
  latest            = false,
  meta              = false,
  revs              = false,
  revs_info         = false)

  query::Dict{AbstractString, Any} = Dict()
  headers::Dict{AbstractString, Any} = Dict("Accept" => "application/json")

  if attachments
    query["attachments"] = true
  end

  if att_encoding_info
    query["att_encoding_info"] = true
  end

  if conflicts
    query["conflicts"] = true
  end

  if deleted_conflicts
    query["deleted_conflicts"] = true
  end

  if latest
    query["latest"] = true
  end

  if meta
    query["meta"] = true
  end

  if revs
    query["revs"] = true
  end

  if revs_info
    query["revs_info"] = true
  end

  if rev != ""
    query["rev"] = rev
  end

  if length(atts_since) > 0
    query["atts_since"] = JSON.json(atts_since)
  end

  if length(open_revs) > 0
    if length(open_revs) == 1 && open_revs[1] == "all"
      query["open_revs"] = "all"
    else
      query["open_revs"] = JSON.json(open_revs)
    end
  end

  relax(get, endpoint(db.url, id); cookies=db.client.cookies, query=query, headers=headers)
end

"""
    result = updatedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing, body=Dict())

Update an existing document, creating a new revision.

Implemented via the _bulk_docs endpoint.

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs)
"""
function updatedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing, body=Dict())
  response = bulkdocs(db, data=[merge(body, Dict("_id" => id, "_rev" => rev))])
  response[1]
end

"""
    result = deletedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing)

Delete a document revision. Implemented via the _bulk_docs endpoint:

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs)
"""
function deletedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing)
  response = bulkdocs(db, data=[Dict("_id" => id, "_rev" => rev, "_deleted" => true)])
  response[1]
end