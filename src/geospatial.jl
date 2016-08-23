"""
    result = geo_index(db::Database, ddoc::AbstractString, name::AbstractString, index::AbstractString)

Create a geospatial index.

The `index` parameter is a string containing an index function in Javascript. 

### Examples

    result = geo_index(db, "geodd", "geoidx", 
      "function(doc){if(doc.geometry&&doc.geometry.coordinates){st_index(doc.geometry);}}"
    )
    
### Returns

Returns a `Dict(...)` from the CouchDB response, of the type

    Dict(
      "ok"  => true, 
      "rev" => "1-b950984b19bb1b8bb43513c9d5b235bc",
      "id"  => "_design/geodd"
    )

[API reference](https://docs.cloudant.com/geo.html)
"""
function geo_index(db::Database, ddoc::AbstractString, name::AbstractString, index::AbstractString)
  data = Dict("st_indexes" => Dict(name => Dict("index" => index)))         
  relax(put, endpoint(db.url, "_design/$ddoc"); json=data, cookies=db.client.cookies)
end

"""
    result = geo_index_info(db::Database, ddoc::AbstractString, name::AbstractString)

Retrieve stats for a geospatial index.

### Examples

    result = geo_index_info(db, "geodd", "geoidx")
    
### Returns

Returns a `Dict(...)` from the CouchDB response, of the type

    Dict(
      "name" => "_design/geodd/geoidx",
      "geo_index" => Dict(
        "doc_count" => 269,
        "disk_size" => 33416,
        "data_size" => 26974
      )
    )

[API reference](https://docs.cloudant.com/geo.html#obtaining-information-about-a-cloudant-geo-index)
"""
function geo_index_info(db::Database, ddoc::AbstractString, name::AbstractString)
  relax(get, endpoint(db.url, "_design/$ddoc/_geo_info/$name"), cookies=db.client.cookies)
end