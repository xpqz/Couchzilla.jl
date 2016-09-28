@testset "Geospatial" begin
  print("\nGeospatial tests\n[  ] Create a geospatial index ")
  result = geo_index(db, "geodd", "geoidx", 
    "function(doc){if(doc.geometry&&doc.geometry.coordinates){st_index(doc.geometry);}}"
  )
  @test result["ok"] == true
  println("\r[OK] Create a geospatial index")

  print("[  ] Get geospatial index info ")
  result = geo_indexinfo(db, "geodd", "geoidx")
  @test haskey(result, "geo_index") == true
  println("\r[OK] Get geospatial index info")

  if geo_database != ""
    geodb = connectdb(cl, database=geo_database)
    print("[  ] Radius geospatial query ")
    result = geo_query(geodb, "geodd", "geoidx";
      lat    = 42.357963,
      lon    = -71.063991,
      radius = 10000.0,
      limit  = 200)
    
    @test length(result["rows"]) == 200
    println("\r[OK] Radius geospatial query")

    print("[  ] Elliptic geospatial query ")
    result = geo_query(geodb, "geodd", "geoidx";
      lat    = 42.357963,
      lon    = -71.063991,
      rangex = 100.0,
      rangey = 500.0,
      limit  = 1)

    @test length(result["rows"]) == 1
    println("\r[OK] Elliptic geospatial query")

    print("[  ] Polygon geospatial query ")
    result = geo_query(geodb, "geodd", "geoidx";
      g="POLYGON ((-71.0537124 42.3681995 0,-71.054399 42.3675178 0,-71.0522962 42.3667409 0,-71.051631 42.3659324 0,-71.051631 42.3621431 0,-71.0502148 42.3618577 0,-71.0505152 42.3660275 0,-71.0511589 42.3670263 0,-71.0537124 42.3681995 0))")
    @test length(result["rows"]) == 2
    println("\r[OK] Polygon geospatial query")

    print("[  ] Radius geospatial query with skip, legacy format and stale=true ")
    result = geo_query(geodb, "geodd", "geoidx";
      skip   = 100,
      format = "legacy",
      nearest = true,
      stale  = true,
      lat    = 42.357963,
      lon    = -71.063991,
      radius = 10000.0,
      limit  = 200)
    @test result["type"] == "FeatureCollection"
    println("\r[OK] Radius geospatial query with skip, legacy format and stale=true")

    print("[  ] Radius geospatial query with bookmark ")
    result = geo_query(geodb, "geodd", "geoidx";
      skip   = 100,
      format = "legacy",
      nearest = true,
      stale  = true,
      lat    = 42.357963,
      lon    = -71.063991,
      radius = 10000.0,
      limit  = 200,
      bookmark = result["bookmark"])
    @test result["type"] == "FeatureCollection"
    println("\r[OK] Radius geospatial query with bookmark")

    print("[  ] Geospatial query with unknown format should fail ")
    @test_throws ErrorException geo_query(geodb, "geodd", "geoidx";
      format = "never-heard-of-it",
      lat    = 42.357963,
      lon    = -71.063991,
      radius = 10000.0)
    println("\r[OK] Geospatial query with unknown format should fail")

    print("[  ] Geospatial query with unknown relation should fail ")
    @test_throws ErrorException geo_query(geodb, "geodd", "geoidx";
      relation = "never-heard-of-it",
      lat    = 42.357963,
      lon    = -71.063991,
      radius = 10000.0)
    println("\r[OK] Geospatial query with unknown relation should fail")

  else 
    println("** Skipping geospatial query tests")
    println("** Replicate https://education.cloudant.com/crimes and set the variable COUCH_GEO_DATABASE")
  end
end
