"""
    result = view_index(db::Database, ddoc::AbstractString, name::AbstractString, map::AbstractString; 
      reduce::AbstractString = "")

Create a secondary index.

The `map` is a string containing a map function in Javascript. Currently, `make_view` 
can only create a single view per design document.

The optional `reduce` parameter is a string containing either a custom Javascript
reducer (best avoided for performance reasons) or the name of a built-in Erlang 
reducer, e.g. `"_stats"`.

### Examples

    result = view_index(db, "my_ddoc", "my_view", "function(doc){if(doc&&doc.name){emit(doc.name,1);}}")
    
### Returns

Returns a `Dict(...)` from the CouchDB response, of the type

    Dict(
      "ok"  => true, 
      "rev" => "1-b950984b19bb1b8bb43513c9d5b235bc",
      "id"  => "_design/my_ddoc"
    )

[API reference](https://docs.cloudant.com/creating_views.html)
"""
function view_index(db::Database, ddoc::AbstractString, name::AbstractString, map::AbstractString; reduce::AbstractString = "")
  data = Dict(
    "views"    => Dict(name => Dict("map" => map)),
    "language" => "javascript"
  )
  
  if reduce != ""
    data["views"][name]["reduce"] = reduce
  end
         
  relax(put, endpoint(db.url, "_design/$ddoc"); json=data, cookies=db.client.cookies)
end

"""
    result = view_query(db::Database, ddoc::AbstractString, name::AbstractString;
      descending    = false,
      endkey        = "",
      include_docs  = false,
      conflicts     = false,
      inclusive_end = true,
      group         = false,
      group_level   = 0,
      reduce        = true,
      key           = "",
      keys          = [],
      limit         = 0,
      skip          = 0,
      startkey      = "")

Query a secondary index.

### Examples

    # Query the view for a known key subset
    result = view_query(db, "my_ddoc", "my_view"; keys=["adam", "billy"])

### Returns

    Dict(
      "rows" => [
        Dict("key" => "adam", "id" => "591c02fa8b8ff14dd4c0553670cc059a", "value" => 1),
        Dict("key" => "billy", "id" => "591c02fa8b8ff14dd4c0553670cc13c1", "value" => 1)
      ],
      "offset" => 0,
      "total_rows" => 7 
    )

[API reference](https://docs.cloudant.com/using_views.html)
"""
function view_query(db::Database, ddoc::AbstractString, name::AbstractString;
  descending    = false,
  endkey        = "",
  include_docs  = false,
  conflicts     = false,
  inclusive_end = true,
  group         = false,
  group_level   = 0,
  reduce        = true,
  key           = "",
  keys          = [],
  limit         = 0,
  skip          = 0,
  startkey      = "")

  query::Dict{String, Any} = Dict()

  if descending
    query["descending"] = true
  end

  if include_docs
    query["include_docs"] = true
  end

  if conflicts
    query["conflicts"] = true
  end
  
  if group
    query["group"] = true
  end
  
  if !reduce
    query["reduce"] = false
  end
    
  if group_level > 0
    query["group_level"] = group_level
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

  url = endpoint(db.url, "_design/$ddoc/_view/$name")
  if length(keys) > 0
    relax(post, url; json=Dict("keys" => keys), cookies=db.client.cookies, query=query)
  else
    relax(get, url; cookies=db.client.cookies, query=query)
  end
end

"""
    alldocs(db::Database;
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

Return all documents in the database by the primary index.

The optional parameters are:

* descending     true/false   -- lexicographical ordering of keys. Default false.
* endkey         id           -- stop when `endkey` is reached. Optional.
* startkey       id           -- start at `startkey`. Optional. 
* include_docs   true/false   -- return the document body. Default false.
* conflicts      true/false   -- also return any conflicting revisions. Default false.
* inclusive_end  true/false   -- if `endkey` is given, should this be included? Default true
* key            id           -- return only specific key. Optional.
* keys           [id, id,...] -- return only specific set of keys (will POST). Optional. 
* limit          int          -- return only max `limit` number of rows. Optional.
* skip           int          -- skip over the first `skip` number of rows. Default 0.

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/bulk-api.html#db-all-docs)
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

  query::Dict{String, Any} = Dict()

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
    relax(post, endpoint(db.url, "_all_docs"); json=Dict("keys" => keys), cookies=db.client.cookies, query=query)
  else
    relax(get, endpoint(db.url, "_all_docs"); cookies=db.client.cookies, query=query)
  end
end
