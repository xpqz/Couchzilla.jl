type Query
  selector
  limit
  skip
  sort
  
  Query(selector::Dict{Any, Any}; 
    limit = 25, 
    skip = 0, 
    sort::Array{Dict{AbstractString, AbstractString}, 1} = []) =
    new(selector, limit, skip, sort)
end

function dictify(query::Query)
  Dict(  
    "selector" => query.selector,
    "limit"    => query.limit,
    "sort"     => query.sort,
    "skip"     => query.skip
  )
end

"""
`result::QueryResult = find(db::Database; 
  selector::Dict{AbstractString, Any} = Dict(), 
  fields::Array{AbstractString, 1} = [], 
  sort::Array{Dict{AbstractString, AbstractString}, 1} = [],
  limit = 0,
  skip = 0)`

Query database (Mango/Cloudant Query). 

Example: find all documents where "year" is greater than 2010, returning 
the fields _id, _rev, year and title, sorted in ascending order on year.
Set the page size to 10.

`find(db;
  selector = Dict("year"=>Dict("\$gt"=>2010)),
  fields   = ["_id", "_rev", "year", "title"],
  sort     = [Dict("year" => "asc")],
  limit    = 10,
  skip     =  0)`
"""
function find(db::Database; 
  selector = Dict(), 
  fields::Array{Any, 1} = [], 
  sort::Array{Dict{Any, Any}, 1} = [],
  limit = 25,
  skip = 0)
  
  cquery = Dict{Any, Any}("selector" => selector, "limit" => limit, "skip" => skip)
  if length(fields) > 0
    cquery["fields"] = fields
  end
    
  result = Requests.json(post(endpoint(db.url, "_find"); json=cquery, cookies=db.client.cookies))
  QueryResult(result["docs"], result["bookmark"]) 
end

"""
`createindex(db::Database; 
  name::AbstractString = "", 
  ddoc::AbstractString = "", 
  fields = [], 
  selector = Dict(),
  type::INDEXTYPE = json)`
  
Create a Mango index. All parameters optional, but note that not giving a 'fields' argument will
result in all fields being indexed which is very costly. Defaults to type 'json'.

Here's a spicy example:

result = Couchzilla.createindex(db; ddoc="my-ddoc", fields=[Dict("name"=>"lastname", "type"=>"string")], 
  indextype=text, default_field=Dict("analyzer" => "german", "enabled" => true))

https://docs.cloudant.com/cloudant_query.html#creating-an-index
"""
function createindex(db::Database; 
  name::AbstractString = "", 
  ddoc::AbstractString = "", 
  fields = [], 
  selector = Dict(),
  default_field = Dict(),
  indextype::INDEXTYPE = json)
      
  if indextype == json && selector != Dict()
    error("Indextype 'json' does not support a selector.")
  end
  
  if indextype == json && fields == []
    error("Indextype 'json' requires a fields specification.")
  end
  
  idxquery = fields == [] ? Dict{Any, Any}("index" => Dict{Any, Any}()) : Dict{Any, Any}("index" => Dict{Any, Any}("fields" => fields))
  
  if indextype == text && default_field != Dict() && fields != []
    idxquery["index"]["default_field"] = default_field
  end
  
  if selector != Dict()
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
