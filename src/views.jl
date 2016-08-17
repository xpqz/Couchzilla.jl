"""
Create a secondary index (a.k.a a view).

```julia
result = make_view(db::Database, 
  ddoc::AbstractString, 
  name::AbstractString, 
  map::AbstractString; 
  reduce::AbstractString = "")
```

The `map` is a string containing a map function in Javascript. Currently can only 
create a single view per design document.

https://docs.cloudant.com/creating_views.html
"""
function make_view(db::Database, ddoc::AbstractString, name::AbstractString, map::AbstractString; reduce::AbstractString = "")
  data = Dict{AbstractString, Any}(
    "views"    => Dict(name => Dict("map" => map)),
    "language" => "javascript"
  )
  
  if reduce != ""
    data["views"][name]["reduce"] = reduce
  end
         
  Requests.json(put(endpoint(db.url, "_design/$ddoc"); json=data, cookies=db.client.cookies))
end

"""
Query a secondary index (a.k.a a view).

```julia
result = query_view(db::Database, ddoc::AbstractString, name::AbstractString;
  descending    = false,
  endkey        = "",
  include_docs  = false,
  conflicts     = false,
  inclusive_end = true,
  group         = false,
  group_level   = 0,
  reduce        = true,
  stale         = false,
  key           = "",
  keys          = [],
  limit         = 0,
  skip          = 0,
  startkey      = "")
```

https://docs.cloudant.com/using_views.html
"""
  
function query_view(db::Database, ddoc::AbstractString, name::AbstractString;
  descending    = false,
  endkey        = "",
  include_docs  = false,
  conflicts     = false,
  inclusive_end = true,
  group         = false,
  group_level   = 0,
  reduce        = true,
  stale         = false,
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
  
  if group
    query["group"] = true
  end
  
  if !reduce
    query["reduce"] = false
  end
  
  if stale
    query["stale"] = true
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
    Requests.json(post(url; json=Dict("keys" => keys), cookies=db.client.cookies, query=query))
  else
    relax(get, url; cookies=db.client.cookies, query=query)
  end
end