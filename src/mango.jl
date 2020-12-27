# The Mango/Cloudant Query API
# 
# See
#
# * https://docs.cloudant.com/cloudant_query.html
# * https://cloudant.com/blog/cloudant-query-grows-up-to-handle-ad-hoc-queries/
# 

"""
    struct QueryResult
      docs::Vector{Dict{AbstractString, Any}}
      bookmark::AbstractString 
    end

Returned by `query(...)`.

`bookmark` is only relevant when querying indexes of type `text`.
"""
struct QueryResult
  docs::Vector{Dict{AbstractString, Any}}
  # Bookmarks only relevant to queries on Lucene indexes (type "text").
  # JSON indexes have to be limit/skipped, as are views underneath
  bookmark::AbstractString 
end

"""
    result = mango_query(db::Database, selector::Selector;
      fields::Any                                        = [],
      sort::Vector{Dict{T, Any}} where T<:AbstractString = Vector{Dict{AbstractString, Any}}(),
      limit                                              = 0,
      skip                                               = 0,
      bookmark                                           = "")

Query database (Mango/Cloudant Query).

See the `Selector` type and the associated `q"..."` custom string literal
which implements a simplified DSL for writing selectors.

### Examples

Find all documents where "year" is greater than 2010, returning 
the fields `_id`, `_rev`, `year` and `title`, sorted in ascending order 
on `year`. Set the page size to 10.

    result = mango_query(db, q"year > 2010";
      fields = ["_id", "_rev", "year", "title"],
      sort   = [Dict("year" => "asc")],
      limit  = 10)

### Returns

    struct QueryResult

* [API reference](https://docs.cloudant.com/cloudant_query.html)
* [Cloudant Query blog post](https://cloudant.com/blog/cloudant-query-grows-up-to-handle-ad-hoc-queries/)
"""
function mango_query(db::Database, selector::Selector;
  fields::Any                                        = [],
  sort::Vector{Dict{T, Any}} where T<:AbstractString = Vector{Dict{AbstractString, Any}}(),
  limit                                              = 0,
  skip                                               = 0,
  bookmark                                           = "")

  body = Dict{String, Any}("selector" => selector.dict, "skip" => skip)
  if length(fields) > 0
    body["fields"] = fields
  end

  if length(sort) > 0
    body["sort"] = sort
  end
  
  if limit > 0
    body["limit"] = limit
  end
  
  if bookmark != ""
    body["bookmark"] = bookmark
  end

  result = relax(HTTP.post, endpoint(db.url, "_find"); json=body, cookies=db.client.cookies)
  QueryResult(result["docs"], haskey(result, "bookmark") ? result["bookmark"] : "")
end

"""
    result = mango_index(db::Database, fields::AbstractArray;
      name::T where T<:AbstractString   = "",
      ddoc::T where T<:AbstractString   = "",
      selector                          = Selector(),
      default_field                     = Dict{String, Any}("analyzer" => "standard", "enabled" => true))

Create a Mango index. 

All `kw` parameters are optional. The fields spec is mandatory for JSON-type indexes. For a 
text index, if you give an empty vector as the fields, it will index every field, which is
occasionally convenient, but a significant performance drain. The index type will defaults to 
type `"json"` and will be assumed to be `"text"` if the data in the `fields` array are `Dict`s. 
Note that the `text` index type is a Cloudant-only feature.

### Examples

* Make a text index (Cloudant only)

    result = mango_index(db, [Dict("name"=>"lastname", "type"=>"string")]; ddoc="my-ddoc",
      default_field=Dict("analyzer" => "german", "enabled" => true))

* Make a json index

  result = mango_index(db, ["data", "data2"])

### Returns

`mango_index()` returns a `Dict(...)` version of the CouchDB response, of the type

    Dict(
      "name"   => "e7d18f69aa0deaa1ffcdf8f705895b61515a6bf6",
      "id"     => "_design/e7d18f69aa0deaa1ffcdf8f705895b61515a6bf6",
      "result" => "created"
    )

[API reference](https://docs.cloudant.com/cloudant_query.html#creating-an-index)
"""
function mango_index(db::Database, fields::AbstractArray;
  name::T where T<:AbstractString = "",
  ddoc::T where T<:AbstractString = "",
  selector                        = Selector(),
  default_field                   = Dict{String, Any}("analyzer" => "standard", "enabled" => true))

  idxquery = fields == [] ? Dict{T where T<:AbstractString, Any}("index" => Dict{T where T<:AbstractString, Any}()) : Dict{T where T<:AbstractString, Any}("index" => Dict{T where T<:AbstractString, Any}("fields" => fields))

  indextype = "json"
  if length(fields) > 0 && isa(fields[1], AbstractDict)
    indextype = "text"
  end

  if !isempty(selector)
    idxquery["selector"] = selector
  end

  if indextype == "json" && !isempty(selector)
    error("Indextype 'json' does not support a selector.")
  end
  
  if indextype == "json" && fields == []
    error("Indextype 'json' requires a fields specification.")
  end
  
  if indextype == "text"
    idxquery["index"]["default_field"] = default_field
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

  relax(HTTP.post, endpoint(db.url, "_index"); json=idxquery, cookies=db.client.cookies)
end

"""
    result = listindexes(db::Database)

List all existing indexes for the database. This includes views, mango and geo indexes in
addition to the primary index.

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
  relax(HTTP.get, endpoint(db.url, "_index"); cookies=db.client.cookies)
end

"""
    result = mango_deleteindex(db::Database; ddoc="", name="", indextype="")
    
Delete a query index given its ddoc, index name and index type.

Indextype is either "text" or "json".

### Returns

`mango_deleteindex()` returns a `Dict(...)` version of the CouchDB response:

    Dict("ok" => true)

[API reference](https://docs.cloudant.com/cloudant_query.html#deleting-an-index)
"""
function mango_deleteindex(db::Database; ddoc="", name="", indextype="")
  if indextype ∉ ["json", "text"]
    error("Bad indextype: $indextype")
  end
  if ddoc == "" || name == ""
    error("Expected a ddoc and index name")
  end

  relax(HTTP.delete, endpoint(db.url, "_index/$ddoc/$indextype/$name"); cookies=db.client.cookies)
end
