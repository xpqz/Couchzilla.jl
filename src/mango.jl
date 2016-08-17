type QueryResult
  docs::Vector{Dict{AbstractString, Any}}
  bookmark::AbstractString
end

"""
Query database (Mango/Cloudant Query).

```julia
query{T<:AbstractString}(db::Database, selector::Selector;
  fields::Vector{T}          = Vector{AbstractString}(),
  sort::Vector{Dict{T, Any}} = Vector{Dict{AbstractString, Any}}(),
  limit                      = 0,
  skip                       = 0,
  bookmark                   = "")
```

See the `Selector` type and the associated `q"..."` custom string literal
which implements a simplified DSL for writing selectors.

Example: find all documents where "year" is greater than 2010, returning 
the fields _id, _rev, year and title, sorted in ascending order on year.
Set the page size to 10.

```julia
query(db, q"year > 2010";
  fields = ["_id", "_rev", "year", "title"],
  sort   = [Dict("year" => "asc")],
  limit  = 10)
```

See 

* https://docs.cloudant.com/cloudant_query.html
* https://cloudant.com/blog/cloudant-query-grows-up-to-handle-ad-hoc-queries/
"""
function query{T<:AbstractString}(db::Database, selector::Selector;
  fields::Vector{T}          = Vector{AbstractString}(),
  sort::Vector{Dict{T, Any}} = Vector{Dict{AbstractString, Any}}(),
  limit                      = 0,
  skip                       = 0,
  bookmark                   = "")

  cquery = Dict{UTF8String, Any}("selector" => selector.dict, "skip" => skip)
  if length(fields) > 0
    cquery["fields"] = fields
  end

  if length(sort) > 0
    cquery["sort"] = sort
  end
  
  if limit > 0
    cquery["limit"] = limit
  end
  
  if bookmark != ""
    cquery["bookmark"] = bookmark
  end

  result = Requests.json(post(endpoint(db.url, "_find"); json=cquery, cookies=db.client.cookies))
  QueryResult(result["docs"], haskey(result, "bookmark") ? result["bookmark"] : "")
end

"""
Create a Mango index. 

```julia
createindex{T<:AbstractString}(db::Database; 
  name::T              = "",
  ddoc::T              = "",
  fields               = Vector{T}(), 
  selector             = Selector(),
  default_field        = Dict{UTF8String, Any}("analyzer" => "standard", "enabled" => true))
```
  
All parameters optional, but note that not giving a `fields` argument will
result in all fields being indexed which is very costly. Defaults to type `"json"` and
will be assumed to be `"text"` if the data in the `fields` array are `Dict`s.

Here's an example:

```julia
result = createindex(db; ddoc="my-ddoc", fields=[Dict("name"=>"lastname", "type"=>"string")], 
  default_field=Dict("analyzer" => "german", "enabled" => true))
```

https://docs.cloudant.com/cloudant_query.html#creating-an-index
"""
function createindex{T<:AbstractString}(db::Database; 
  name::T              = "",
  ddoc::T              = "",
  fields               = Vector{T}(), 
  selector             = Selector(),
  default_field        = Dict{UTF8String, Any}("analyzer" => "standard", "enabled" => true))

  indextype = "json"
  if length(fields) > 0 && isa(fields[1], Dict)
    indextype = "text"
  end

  if indextype == "json" && !isempty(selector)
    error("Indextype 'json' does not support a selector.")
  end
  
  if indextype == "json" && fields == []
    error("Indextype 'json' requires a fields specification.")
  end
  
  idxquery = fields == [] ? Dict{T, Any}("index" => Dict{T, Any}()) : Dict{T, Any}("index" => Dict{T, Any}("fields" => fields))
  
  if indextype == "text"
    idxquery["index"]["default_field"] = default_field
  end
  
  if !isempty(selector)
    idxquery["selector"] = selector
  end
  
  if name != ""
    idxquery["name"] = name
  end
  
  if ddoc != ""
    idxquery["ddoc"] = ddoc
  end
  
  if indextype != "json"
    idxquery["type"] = "text"
  end
  
  Requests.json(post(endpoint(db.url, "_index"); json=idxquery, cookies=db.client.cookies))
end
