relations = Dict{UTF8String, Bool}(
  "contains"           => true,
  "contains_properly"  => true,
  "covered_by"         => true,
  "covers"             => true,
  "crosses"            => true,
  "disjoint"           => true,
  "intersects"         => true,
  "overlaps"           => true,
  "touches"            => true,
  "within"             => true
)

formats = Dict{UTF8String, Bool}(
  "legacy"                   => true,
  "geojson"                  => true,
  "view"                     => true,
  "application/vnd.geo+json" => true
)

# WKT = Dict{UTF8String, Bool}(
#   "point"              => true,
#   "linestring"         => true,
#   "polygon"            => true,
#   "multipoint"         => true,
#   "multilinestring"    => true,
#   "multipolygon"       => true,
#   "geometrycollection" => true
# )

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

"""
https://education.cloudant.com/crimes/_design/geodd/_geo/geoidx?lat=42.357963&lon=-71.063991&radius=10000&limit=200&include_docs=true

Boston Commercial Street corridor polyon
https://education.cloudant.com/crimes/_design/geodd/_geo/geoidx?relation=contains&g=POLYGON%20((-71.0537124%2042.3681995%200,-71.054399%2042.3675178%200,-71.0522962%2042.3667409%200,-71.051631%2042.3659324%200,-71.051631%2042.3621431%200,-71.0502148%2042.3618577%200,-71.0505152%2042.3660275%200,-71.0511589%2042.3670263%200,-71.0537124%2042.3681995%200))&include_docs=true';
"""

function geo_query(db::Database, ddoc::AbstractString, name::AbstractString;
  lat::Float64    = -360.0, # -90:90 valid range (degrees)
  lon::Float64    = -360.0, # -180:180 valid range (degrees)
  rangex::Float64 = 0.0,
  rangey::Float64 = 0.0,
  radius::Float64 = 0.0,
  bbox::Vector{Float64}  = Vector{Float64}(),
  relation::AbstractString = "intersects",
  nearest = false,
  bookmark::AbstractString = "",
  format::AbstractString = "view", # legacy | geojson | view | application/vnd.geo+json
  skip = 0,
  limit = 0,
  stale = false,
  g::AbstractString = "") # We really need GeoJSON to do this properly

  query::Dict{UTF8String, Any} = Dict()

  if lat != -360.0
    query["lat"] = lat
  end

  if lon != -360.0
    query["lon"] = lon
  end

  if rangex > 0.0
    query["rangex"] = rangex
  end

  if rangey > 0.0
    query["rangey"] = rangey
  end

  if radius > 0.0
    query["radius"] = radius
  end

  if g != "" # We really need GeoJSON to do this properly
    query["g"] = g
  end

  if length(bbox) == 4
    query["bbox"] = bbox
  end

  if !haskey(relations, lowercase(relation))
    error("Unknown relation: '$relation'")
  end
  if relation != "intersects"
    query["relation"] = relation
  end

  if !haskey(formats, lowercase(format))
    error("Unknown format: '$format'")
  end
  if format != "view"
    query["format"] = format
  end

  if bookmark != ""
    query["bookmark"] = bookmark
  end

  if nearest
    query["nearest"] = true
  end

  if stale
    query["stale"] = "ok" # ffs
  end

  if skip > 0
    query["skip"] = skip
  end

  if limit > 0
    query["limit"] = limit
  end

  relax(get, endpoint(db.url, "_design/$ddoc/_geo/$name"); cookies=db.client.cookies, query=query)
end
