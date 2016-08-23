# The Mango/Cloudant Query API
# 
# See
#
# * https://docs.cloudant.com/cloudant_query.html
# * https://cloudant.com/blog/cloudant-query-grows-up-to-handle-ad-hoc-queries/
# 

"""
    type QueryResult
      docs::Vector{Dict{AbstractString, Any}}
      bookmark::AbstractString 
    end

Returned by `query(...)`.

`bookmark` is only relevant when querying indexes of type `text`.
"""
type QueryResult
  docs::Vector{Dict{AbstractString, Any}}
  # Bookmarks only relevant to queries on Lucene indexes (type "text").
  # JSON indexes have to be limit/skipped, as are views underneath
  bookmark::AbstractString 
end

"""
    result = query{T<:AbstractString}(db::Database, selector::Selector;
      fields::Vector{T}          = Vector{AbstractString}(),
      sort::Vector{Dict{T, Any}} = Vector{Dict{AbstractString, Any}}(),
      limit                      = 0,
      skip                       = 0,
      bookmark                   = "")

Query database (Mango/Cloudant Query).

See the `Selector` type and the associated `q"..."` custom string literal
which implements a simplified DSL for writing selectors.

### Examples

Find all documents where "year" is greater than 2010, returning 
the fields `_id`, `_rev`, `year` and `title`, sorted in ascending order 
on `year`. Set the page size to 10.

    result = query(db, q"year > 2010";
      fields = ["_id", "_rev", "year", "title"],
      sort   = [Dict("year" => "asc")],
      limit  = 10)

### Returns

    type QueryResult

* [API reference](https://docs.cloudant.com/cloudant_query.html)
* [Cloudant Query blog post](https://cloudant.com/blog/cloudant-query-grows-up-to-handle-ad-hoc-queries/)
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

  result = relax(post, endpoint(db.url, "_find"); json=cquery, cookies=db.client.cookies)
  QueryResult(result["docs"], haskey(result, "bookmark") ? result["bookmark"] : "")
end

"""
    result = createindex{T<:AbstractString}(db::Database; 
      name::T       = "",
      ddoc::T       = "",
      fields        = Vector{T}(), 
      selector      = Selector(),
      default_field = Dict{UTF8String, Any}("analyzer" => "standard", "enabled" => true))

Create a Mango index. 

All `kw` parameters are optional, but note that not giving a `fields` argument will
result in all fields being indexed which is very costly. Defaults to type `"json"` and
will be assumed to be `"text"` if the data in the `fields` array are `Dict`s.

### Examples

* Make a text index

    result = createindex(db; ddoc="my-ddoc", fields=[Dict("name"=>"lastname", "type"=>"string")], 
      default_field=Dict("analyzer" => "german", "enabled" => true))

* Make a json index

  result = createindex(db; fields=["data", "data2"])

### Returns

`createindex()` returns a `Dict(...)` version of the CouchDB response, of the type

    Dict(
      "name"   => "e7d18f69aa0deaa1ffcdf8f705895b61515a6bf6",
      "id"     => "_design/e7d18f69aa0deaa1ffcdf8f705895b61515a6bf6",
      "result" => "created"
    )

[API reference](https://docs.cloudant.com/cloudant_query.html#creating-an-index)
"""
function createindex{T<:AbstractString}(db::Database; 
  name::T       = "",
  ddoc::T       = "",
  fields        = Vector{T}(), 
  selector      = Selector(),
  default_field = Dict{UTF8String, Any}("analyzer" => "standard", "enabled" => true))

  indextype = "json"
  if length(fields) > 0 && isa(fields[1], Associative)
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
  
  relax(post, endpoint(db.url, "_index"); json=idxquery, cookies=db.client.cookies)
end

"""
    result = listindexes(db::Database)

List all existing indexes for the database. Note that this includes indexes not created 
via the `createindex()` function, such as the primary index and secondary indexes created 
as map-reduce views.

### Returns

`listindexes()` returns a `Dict(...)` version of the CouchDB response:

    Dict(
      "indexes" => [
        Dict(
          "name" => "_all_docs",
          "def"  => Dict(
            "fields" => [Dict("_id" => "asc")]
          ),
          "ddoc" => nothing,
          "type" => "special"
        ),
        Dict(
          "ddoc" => "_design/cc79a71f562af7ef36deafe511fea9a857b05bcc",
          "name" => "cc79a71f562af7ef36deafe511fea9a857b05bcc",
          "type" => "text",
          "def"  => Dict(
            "index_array_lengths" => true,
            "fields" => [Dict("cust" => "string"), Dict("value" => "string")],
            "default_field" => Dict(
              "analyzer" => "standard", 
              "enabled" => true
            ), 
            "selector" => Dict(),
            "default_analyzer" => "keyword"
          )
        ), 
        # ...
      ]
    )
    
[API reference](https://docs.cloudant.com/cloudant_query.html#list-all-cloudant-query-indexes)
"""
function listindexes(db::Database)
  relax(get, endpoint(db.url, "_index"); cookies=db.client.cookies)
end

"""
    result = deleteindex(db::Database; ddoc="", name="", indextype="")
    
Delete a query index given its ddoc, index name and index type.

Indextype is either "text" or "json".

### Returns

`deleteindex()` returns a `Dict(...)` version of the CouchDB response:

    Dict("ok" => true)

[API reference](https://docs.cloudant.com/cloudant_query.html#deleting-an-index)
"""
function deleteindex(db::Database; ddoc="", name="", indextype="")
  if indextype ∉ ["json", "text"]
    error("Bad indextype: $indextype")
  end
  if ddoc == "" || name == ""
    error("Expected a ddoc and index name")
  end
    
  relax(delete, endpoint(db.url, "_index/$ddoc/$indextype/$name"); cookies=db.client.cookies)
end
