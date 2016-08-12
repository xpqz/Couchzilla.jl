type QueryResult
  docs::Vector{Dict{AbstractString, Any}}
  bookmark::AbstractString
end

"""
`result::QueryResult = find(db::Database, selector::Selector;
  fields::Array{AbstractString, 1}} = [],
  sort::Array{Dict{AbstractString, Any}, 1}} = [],
  limit  = 25,
  skip   = 0)`

Query database (Mango/Cloudant Query). 

Example: find all documents where "year" is greater than 2010, returning 
the fields _id, _rev, year and title, sorted in ascending order on year.
Set the page size to 10.

`find(db, r"year > 2010";
  fields = ["_id", "_rev", "year", "title"],
  sort   = [Dict("year" => "asc")],
  limit  = 10)`
  
"""
function find{T<:AbstractString}(db::Database, selector::Selector;
  fields::Vector{T}          = Vector{AbstractString}(),
  sort::Vector{Dict{T, Any}} = Vector{Dict{AbstractString, Any}}(),
  limit                        = 25,
  skip                         = 0)

  cquery = Dict{UTF8String, Any}("selector" => selector.dict, "limit" => limit, "skip" => skip)
  if length(fields) > 0
    cquery["fields"] = fields
  end

  if length(sort) > 0
    cquery["sort"] = sort
  end

  result = Requests.json(post(endpoint(db.url, "_find"); json=cquery, cookies=db.client.cookies))
  QueryResult(result["docs"], haskey(result, "bookmark") ? result["bookmark"] : "")
end

"""
`createindex(db::Database; 
  name          = Nullable{AbstractString}(),
  ddoc          = Nullable{AbstractString}(),
  fields        = Nullable{Array{AbstractString, 1}}(), 
  selector      = Nullable{Selector}(),
  default_field = Nullable{Dict{Any, Any}}(),
  indextype     = json)`
  
Create a Mango index. All parameters optional, but note that not giving a 'fields' argument will
result in all fields being indexed which is very costly. Defaults to type 'json'.

Here's an example:

result = Couchzilla.createindex(db; ddoc="my-ddoc", fields=[Dict("name"=>"lastname", "type"=>"string")], 
  indextype=text, default_field=Dict("analyzer" => "german", "enabled" => true))

https://docs.cloudant.com/cloudant_query.html#creating-an-index
"""
function createindex{T<:AbstractString}(db::Database; 
  name::T              = "",
  ddoc::T              = "",
  fields::Vector{T}    = [], 
  selector             = Selector(),
  default_field        = Dict("analyzer" => "standard", "enabled" => true),
  indextype::INDEXTYPE = json)
      
  if indextype == json && !isempty(selector)
    error("Indextype 'json' does not support a selector.")
  end
  
  if indextype == json && fields == []
    error("Indextype 'json' requires a fields specification.")
  end
  
  idxquery = fields == [] ? Dict{T, Any}("index" => Dict{T, Any}()) : Dict{T, Any}("index" => Dict{T, Any}("fields" => fields))
  
  if indextype == text
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
  
  if indextype != json
    idxquery["type"] = string(indextype)
  end
  
  Requests.json(post(endpoint(db.url, "_index"); json=idxquery, cookies=db.client.cookies))
end
