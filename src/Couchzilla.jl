__precompile__()

"""
The CouchDB API

This module follows the example set by PouchDB of implementing all
write operations via the CouchDB _bulk_docs end point, instead of
 the mess of a mixture of POST, PUT and DELETE. The advantage of this
is much simpler code paths.

There are some side effects of this, notably that some parameters 
that the other end points support isn't supported here.
"""

# using Couchzilla
# importall Couchzilla
#
# client = Client("skruger", "cloudantbaloo1129", "https://skruger.cloudant.com")
# db, created = createdb(client; database="mynewdb")
# createindex(db; fields=["name", "data"])
# createdoc(db; data=[
#     Dict("name"=>"adam", "data"=>"hello"),
#     Dict("name"=>"billy", "data"=>"world"),
#     Dict("name"=>"cecilia", "data"=>"authenticate"),
#     Dict("name"=>"davina", "data"=>"cloudant"),
#     Dict("name"=>"eric", "data"=>"blobbyblobbyblobby")
# ])
# query(db, q"name=davina")
# deletedb(client, "mynewdb")
# make_view(db, "my_ddoc", "my_view", 
# """
# function(doc) {
#   if(doc && doc.name) {
#     emit(doc.name, 1);
#   }
# }""")

module Couchzilla

using Requests
using URIParser
using JSON

import Requests: get, post, put, delete, requestfor, headers

@enum INDEXTYPE json=1 text=2

function Base.show(io::IO, idx::INDEXTYPE)
  print(io, idx==json ? "json" : "text")
end

immutable HTTPException <: Exception 
  status
  response
  request
end

function Base.show(io::IO, err::HTTPException)
  print(io, "HTTPException - status: $(err.status) request: $(err.request) response: $(err.response)")
end

type Client
  username
  password
  url
  cookies

  Client(username::AbstractString, password::AbstractString, urlstr::AbstractString) = 
    cookieauth(new(username, password, URI(urlstr)))
end

"""
The Database immutable is a client connection tied to a specific remote DB. It is normally
not created directly, but via a call to `connect(client; database=dbname)`. Note that
this doesn't verify that the database exists. 

You can also use

```julia
db, created = createdb(client; database="mydb")
```
"""
immutable Database
  url
  name
  client

  Database(client::Client, name::AbstractString) =
    new(URI(client.url.scheme, client.url.host, client.url.port, "/$name"), name, client)
end

# Private functions
"""
`relax()` makes an HTTP request with the relevant cookies and query strings
and deserialises the response, assumed to be json.
"""
function relax(fun, url_string; cookies=nothing, query=Dict(), headers=Dict())
  if cookies == nothing
    error("Not authenticated")
  end
  response = fun(url_string; cookies=cookies, query=query, headers=headers)
  if response.status in 400:599
    request = requestfor(response)
    throw(HTTPException(response.status, Requests.json(response), string(request)))
  else
    Requests.json(response)
  end
end

"""
`cookieauth()` hits the `_session` endpoint to obtain a session cookie
that is used to authenticate subsequent requests.
"""
function cookieauth(client::Client)
  response = post(endpoint(client.url, "_session"); 
    data=Dict("name" => client.username, "password" => client.password))
  client.cookies = cookies(response)
  client
end

"""
`endpoint()` appends a path string to the current URI
"""
function endpoint(uri::URI, path::AbstractString)
  string(URI(uri.scheme, uri.host, uri.port, replace("$(uri.path)/$path", "//", "/")))
end

"""
Return an immutable Database reference. 

```julia
db = connect(client::Client; database::AbstractString=nothing)
```

Subsequent database-level operations will operate on the chosen database. 
If you need to operate on a different database, you need to create a new 
Database reference. `connect(...)` does not check that the chosen remote 
database exists.
"""
function connect(client::Client; database::AbstractString=nothing) 
  Database(client, database)
end

"""
Create a new database on the remote end called `dbname`. Return an immutable Database
reference to this newly created db, and the true if a database was created, false if it
already existed.

```julia
db, created = createdb(client::Client; databse::AbstractString=nothing)
```

See

http://docs.couchdb.org/en/1.6.1/api/database/common.html#put--db
"""
function createdb(client::Client; database::AbstractString=nothing)
  db = Database(client, database)
  created = false
  try 
    response = relax(put, string(db.url); cookies=client.cookies)
    created = true
  catch err
    # A 412 (db already exists) isn't always a fatal error. 
    # We bubble this up in the second returned value and leave
    # it to the user to decide.
    if !isa(err, HTTPException) || err.status != 412
      rethrow()
    end
  end
  return db, created
end

"""
Return the meta data about the `dbname` database.

```julia
info = dbinfo(client::Client, name::AbstractString)
```

See 

http://docs.couchdb.org/en/1.6.1/api/database/common.html#get--db
"""
function dbinfo(client::Client, name::AbstractString)
  relax(get, endpoint(client.url, name); cookies=client.cookies)
end

"""
Return a list of all databases under the authenticated user.

```julia
dblist = listdbs(client::Client)
```

See

http://docs.couchdb.org/en/1.6.1/api/server/common.html#all-dbs
"""
function listdbs(client::Client)
  relax(get, endpoint(client.url, "_all_dbs"); cookies=client.cookies)
end

"""
Delete the named database.

```julia
result = deletedb(client::Client, name::AbstractString)
```

See

http://docs.couchdb.org/en/1.6.1/api/database/common.html?#delete--db
"""
function deletedb(client::Client, name::AbstractString)
  relax(delete, endpoint(client.url, name); cookies=client.cookies)
end

"""

Raw _bulk_docs.

```julia
result = bulkdocs(db::Database; data=[], options=Dict())
```

This is a function primarily intended for internal use, but can
be used directly to create, update or delete documents in bulk,
so as to save on the HTTP overhead.

See

http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs
"""
function bulkdocs(db::Database; data=[], options=Dict())
  post_url = endpoint(db.url, "_bulk_docs")
  Requests.json(post(post_url; json=Dict("docs" => data), cookies=db.client.cookies, query=options))
end

"""
Create a new document.

```julia
result = create(db::Database; body=Dict())
```

Note that this is implemented via the `_bulk_docs` endpoint, rather 
than a POST to the /{DB}.

http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs
"""
function createdoc(db::Database, body=Dict())
  response = bulkdocs(db; data=[body])
  response[1]
end

"""
Bulk create a set of new documents.

```julia
result = create(db::Database; data=[Dict()])
```

This is implemented via the `_bulk_docs` endpoint. See

http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs
"""
function createdoc(db::Database; data=[Dict()])
  if length(data) == 0
    error("No data given")
  end
  
  bulkdocs(db; data=data)
end

"""
Fetch a document by `id`.

```julia
readdoc(db::Database, id::AbstractString; 
  rev               = "", 
  attachments       = false, 
  att_encoding_info = false,
  atts_since        = [],
  conflicts         = false,
  deleted_conflicts = false,
  latest            = false,
  meta              = false,
  open_revs         = [],
  revs              = false,
  revs_info         = false)
```

For a description of the parameters, see

# http://docs.couchdb.org/en/1.6.1/api/document/common.html#get--db-docid
"""
function readdoc(db::Database, id::AbstractString; 
  rev               = "", 
  attachments       = false, 
  att_encoding_info = false,
  atts_since        = [],
  conflicts         = false,
  deleted_conflicts = false,
  latest            = false,
  meta              = false,
  open_revs         = [],
  revs              = false,
  revs_info         = false)

  query::Dict{AbstractString, Any} = Dict()

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
    query["atts_since"] = atts_since
  end

  if length(open_revs) > 0
    query["open_revs"] = open_revs
  end

  relax(get, endpoint(db.url, id); cookies=db.client.cookies, query=query)
end

"""
Update an existing document, creating a new revision.

```julia
result = update(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing, body=Dict())
```

Implemented via the _bulk_docs endpoint:

http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs
"""
function updatedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing, body=Dict())
  response = bulkdocs(db, data=[merge(body, Dict("_id" => id, "_rev" => rev))])
  response[1]
end

"""
Delete a document revision.

```julia
result = delete(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing)
```

Implemented via the _bulk_docs endpoint:

http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html?#post--db-_bulk_docs
"""
function deletedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing)
  response = bulkdocs(db, data=[Dict("_id" => id, "_rev" => rev, "_deleted" => true)])
  response[1]
end

"""
Return all documents in the database by the primary index.

```julia
data = list(db::Database; ...options...)
```

The optional parameters are:

  descending     true/false   -- lexicographical ordering of keys. Default false.
  endkey         id           -- stop when `endkey` is reached. Optional.
  startkey       id           -- start at `startkey`. Optional. 
  include_docs   true/false   -- return the document body. Default false.
  conflicts      true/false   -- also return any conflicting revisions. Default false.
  inclusive_end  true/false   -- if `endkey` is given, should this be included? Default true
  key            id           -- return only specific key. Optional.
  keys           [id, id,...] -- return only specific set of keys (will POST). Optional. 
  limit          int          -- return only max `limit` number of rows. Optional.
  skip           int          -- skip over the first `skip` number of rows. Default 0.

For a more detailed description of the various options, see:

http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html#db-all-docs
"""
function alldocs(db::Database;
  descending    = false,
  endkey        = "",
  include_docs  = false,
  conflicts     = false,
  inclusive_end = true,
  key           = "",
  keys          = [],
  limit         = 0,
  skip          = 0,
  startkey      = "")

  query::Dict{UTF8String, Any} = Dict()

  if descending
    query["descending"] = true
  end

  if include_docs
    query["include_docs"] = true
  end

  if conflicts
    query["conflicts"] = true
  end

  if !inclusive_end
    query["inclusive_end"] = false
  end

  if endkey != ""
    query["endkey"] = JSON.json(endkey)
  end

  if key != ""
    query["key"] = JSON.json(key)
  end

  if limit > 0
    query["limit"] = limit
  end

  if skip > 0
    query["skip"] = skip
  end

  if startkey != ""
    query["startkey"] = JSON.json(startkey)
  end

  if length(keys) > 0
    Requests.json(post(endpoint(db.url, "_all_docs"); json=Dict("keys" => keys), cookies=db.client.cookies, query=query))
  else
    relax(get, endpoint(db.url, "_all_docs"); cookies=db.client.cookies, query=query)
  end
end

include("selector.jl")
include("query.jl")
include("attachments.jl")
include("replication.jl")
include("views.jl")

export Client, Database, HTTPException, INDEXTYPE, QueryResult, Selector
export @q_str, createdb, connect, dbinfo, listdbs, deletedb, createdoc
export readdoc, updatedoc, deletedoc, alldocs, changes, query, createindex
export and, or, nor, not, put_attachment, get_attachment, delete_attachment
export make_view, query_view

end # module