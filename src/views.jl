function make_view(db::Database, ddoc::AbstractString, name::AbstractString, map::AbstractString; reduce::AbstractString = "")
  data = Dict{AbstractString, Any}(
    "views"    => Dict(name => Dict("map" => map)),
    "language" => "javascript"
  )
  
  if reduce != ""
    data["views"][name]["reduce"] = reduce
  end
         
  Requests.json(put(endpoint(db.url, "_design/$ddoc"); json = data, cookies = db.client.cookies))
end

function query_view(db::Database, ddoc::AbstractString, name::AbstractString; query=Dict())         
  Requests.json(get(endpoint(db.url, "_design/$ddoc"); cookies=db.client.cookies, query=query))
end