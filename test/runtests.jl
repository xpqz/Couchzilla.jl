#!/usr/bin/env julia

using Couchzilla
using Base.Test

username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST_URL"]

geo_database = ""
if haskey(ENV, "COUCH_GEO_DATABASE")
  geo_database = ENV["COUCH_GEO_DATABASE"]
end

database = "juliatest-$(Base.Random.uuid4())"
geo_database = "crimes"
cl = Client(username, password, host)
db, created = createdb(cl, database=database)

test_handler(r::Test.Success) = nothing

function test_handler(r::Test.Failure)
  println("\n[INFO] Deleting test database on failure")
  deletedb(cl, database)
  error("Test failed: $(r.expr)")
end

function test_handler(r::Test.Error)
  println("\n[INFO] Deleting test database on failure")
  deletedb(cl, database)
  rethrow(r)
end

Test.with_handler(test_handler) do
  print("[  ] Create test database: $database")
  @test created == true
  println("\r[OK] Create test database: $database")

  print("[  ] DBInfo ")
  result = dbinfo(cl, database)
  @test result["doc_count"] == 0
  println("\r[OK] DBInfo")

  print("[  ] List dbs ")
  result = listdbs(cl)
  @test database ∈ result
  println("\r[OK] List dbs")
end

Test.with_handler(test_handler) do
  print("[  ] Read a non-existing id ")
  @test_throws HTTPException readdoc(db, "this-id-does-not-exist")
  println("\r[OK] Read a non-existing id")
end

Test.with_handler(test_handler) do
  print("[  ] Create new doc ")
  data = createdoc(db, Dict("item" => "flange", "location" => "under-stairs cupboard"))
  @test haskey(data, "id")
  @test haskey(data, "rev")
  println("\r[OK] Create new doc")

  print("[  ] Create new doc with empty body should fail ")
  @test_throws ErrorException createdoc(db)
  println("\r[OK] Create new doc with empty body should fail")

  print("[  ] Read new doc by {id, rev} (note: bad idea usually) ")
  doc = readdoc(db, data["id"]; rev=data["rev"])
  @test haskey(doc, "item")
  @test doc["item"] == "flange"
  println("\r[OK] Read new doc by {id, rev} (note: bad idea usually)")
  print("[  ] Read doc with exotic params ")
  docs = readdoc(db, data["id"]; 
    open_revs=[data["rev"]],
    conflicts=true, 
    attachments=true, 
    atts_since=[data["rev"]],
    att_encoding_info=true, 
    latest=true, 
    meta=true, 
    deleted_conflicts=true,
    revs=true,
    revs_info=true
  )
   
  doc = docs[1]["ok"]
  @test haskey(doc, "item")
  @test doc["item"] == "flange"
  println("\r[OK] Read doc with exotic params")

  print("[  ] Read doc with all open revs ")
  docs = readdoc(db, data["id"]; open_revs=["all"])
  doc = docs[1]["ok"]
  @test haskey(doc, "item")
  @test doc["item"] == "flange"
  println("\r[OK] Read doc with all open revs")

  print("[  ] Reading doc by id and bad rev should fail ")
  @test_throws HTTPException readdoc(db, data["id"]; rev="3-63453748494907")
  println("\r[OK] Reading doc by id and bad rev should fail")
  
  print("[  ] Update existing doc ")
  doc = updatedoc(db; id=data["id"], rev=data["rev"], body=Dict("item" => "flange", "location" => "garage"))
  @test haskey(doc, "rev")
  @test contains(doc["rev"], "2-")
  println("\r[OK] Update existing doc")

  print("[  ] Delete doc ")
  newdoc = deletedoc(db; id=doc["id"], rev=doc["rev"])
  @test newdoc["ok"] == true
  println("\r[OK] Delete doc")
end

Test.with_handler(test_handler) do
  print("[  ] Create a json Mango index ")
  result = mango_index(db, ["data", "data2"]; name="myindex", ddoc="mangoddoc")
  @test result["result"] == "created"
  println("\r[OK] Create a json Mango index")

  print("[  ] Create a json Mango index with a selector should fail ")
  @test_throws ErrorException mango_index(db, ["data", "data2"]; selector=q"data = bob")
  println("\r[OK] Create a json Mango index with a selector should fail")

  print("[  ] Create a json Mango index without fields should fail ")
  @test_throws ErrorException mango_index(db, [])
  println("\r[OK] Create a json Mango index without fields should fail")

  print("[  ] Bulk load data ")
  data=[
      Dict("name"=>"adam",    "data"=>"hello",              "data2" => "television"),
      Dict("name"=>"billy",   "data"=>"world",              "data2" => "vocabulary"),
      Dict("name"=>"bob",     "data"=>"world",              "data2" => "organize"),
      Dict("name"=>"cecilia", "data"=>"authenticate",       "data2" => "study"),
      Dict("name"=>"frank",   "data"=>"authenticate",       "data2" => "region"),    
      Dict("name"=>"davina",  "data"=>"cloudant",           "data2" => "research"),
      Dict("name"=>"eric",    "data"=>"blobbyblobbyblobby", "data2" => "knowledge")
  ]
    
  result = createdoc(db; data=data)
  @test length(result) == length(data)
  println("\r[OK] Bulk load data")
    
  print("[  ] Simple Mango query (equality) ")
  result = mango_query(db, q"data = authenticate"; fields=["name", "data2"])
  @test length(result.docs) == 2
  println("\r[OK] Simple Mango query (equality)")

   print("[  ] Simple Mango query (negation) ")
  result = mango_query(db, not(q"data = authenticate"))
  @test length(result.docs) == 5
  println("\r[OK] Simple Mango query (negation)")

  print("[  ] Selector from raw json ")
  result = mango_query(db, Selector("{\"data\":{\"\$eq\":\"authenticate\"}}"))
  @test length(result.docs) == 2
  println("\r[OK] Selector from raw json")
  
  print("[  ] Compound Mango query (and) ")
  result = mango_query(db, and([q"data = world", q"data2 = vocabulary"]))
  @test length(result.docs) == 1
  @test result.docs[1]["name"] == "billy"
  println("\r[OK] Compound Mango query (and)")
  
  print("[  ] Compound Mango query (or) ")
  result = mango_query(db, or([q"data = world", q"data2 = region"]))
  @test length(result.docs) == 3
  println("\r[OK] Compound Mango query (or)")
  
  print("[  ] Create a text Mango index ")
  textindex = mango_index(db, [
    Dict("name" => "cust",  "type" => "string"), 
    Dict("name" => "value", "type" => "string")
  ])
  @test textindex["result"] == "created"
  println("\r[OK] Create a text Mango index")
  
  maxdoc = 102
  createdoc(db; data=[Dict("cust" => "john", "value" => "hello$x") for x=1:maxdoc])
  print("[  ] Mango query with multi-page return ")
  result = mango_query(db, q"cust=john")
  count = length(result.docs)
  while length(result.docs) > 0
    result = mango_query(db, q"cust = john", bookmark=result.bookmark)
    count += length(result.docs)
  end
  @test count == maxdoc
  println("\r[OK] Mango query with multi-page return")

  print("[  ] Multi-page Mango query as a Task ")
  createdoc(db; data=[Dict("data" => "paged", "data2" => "world$x") for x=1:maxdoc])
  total = 0
  for page in @task paged_mango_query(db, q"data = paged"; pagesize=10)
    total += length(page.docs)
  end
  @test total == maxdoc
  println("\r[OK] Multi-page Mango query as a Task ")

  print("[  ] List indexes ")
  result = listindexes(db)
  @test length(result["indexes"]) == 3
  println("\r[OK] List indexes")
  
  print("[  ] Delete Mango index ")
  result = mango_deleteindex(db; ddoc=textindex["id"], name=textindex["name"], indextype="text")
  @test result["ok"] == true
  println("\r[OK] Delete Mango index")

  print("[  ] Delete Mango index with bad index type ")
  @test_throws ErrorException mango_deleteindex(db; ddoc=textindex["id"], name=textindex["name"], indextype="book")
  println("\r[OK] Delete Mango index with bad index type")

  print("[  ] Delete Mango index with no name ")
  @test_throws ErrorException mango_deleteindex(db; ddoc=textindex["id"], indextype="json")
  println("\r[OK] Delete Mango index with no name")

end

Test.with_handler(test_handler) do
  print("[  ] Streaming changes ")
  count = 0
  maxch = 5
  for ch in @task changes_streaming(db; limit=maxch)
    count += 1
  end
  @test count == maxch + 1 # In stream mode, last item is the CouchDB "last_seq" so need to add 1.
  println("\r[OK] Streaming changes")

  print("[  ] Static changes ")
  data = changes(db; limit=maxch, conflicts=true, include_docs=true, attachments=true, att_encoding_info=true)
  @test maxch == length(data["results"]) # In static mode, "last_seq" is a key in the dict.
  println("\r[OK] Static changes")

  print("[  ] Filtered changes ")
  data2 = changes(db; doc_ids=[data["results"][1]["id"], data["results"][2]["id"], data["results"][3]["id"]])
  @test length(data2["results"]) == 3 
  println("\r[OK] Filtered changes")

  print("[  ] Streaming changes, filtered ")
  count = 0
  for ch in @task changes_streaming(db; doc_ids=[data["results"][1]["id"], data["results"][2]["id"], data["results"][3]["id"]])
    count += 1
  end
  @test count > 0 
  println("\r[OK] Streaming changes, filtered")

  print("[  ] revs_diff ")
  fakerev = "2-1f0e2f0d841ba6b7e3d735b870ebeb8c"
  fakerevs = Dict(data["results"][1]["id"] => [data["results"][1]["changes"][1]["rev"], fakerev])
  diff = revs_diff(db; data=fakerevs)
  @test haskey(diff, data["results"][1]["id"])
  @test diff[data["results"][1]["id"]]["missing"][1] == fakerev
  println("\r[OK] revs_diff")

  print("[  ] bulk_get (note: needs CouchDB2 or Cloudant DBNext) ")
  fetchdata = [ 
    Dict{UTF8String, UTF8String}("id" => data["results"][1]["id"], "rev" => data["results"][1]["changes"][1]["rev"]),
  ]
  response = bulk_get(db; data=fetchdata)
  @test length(response["results"]) == 1
  println("\r[OK] bulk_get (note: needs CouchDB2 or Cloudant DBNext)")
end

#if !haskey(ENV, "TRAVIS")
  Test.with_handler(test_handler) do
    print("[  ] Upload attachment (blob mode) ")
    data = createdoc(db, Dict("item" => "screenshot"))
    result = put_attachment(db, data["id"], data["rev"], "test.png", "image/png", "../data/test.png")
    @test result["ok"] == true
    println("\r[OK] Upload attachment (blob mode)")
    
    print("[  ] Retrieve attachment (blob mode) ")
    att = get_attachment(db, result["id"], "test.png"; rev=result["rev"])
    open("../data/fetched.png", "w") do f
      write(f, att)
    end
    
    # md5_fetched = chomp(readall(`md5 -q ../data/fetched.png`))
    # md5_orig = chomp(readall(`md5 -q ../data/test.png`))
    # @test md5_fetched == md5_orig
    rm("../data/fetched.png")
    println("\r[OK] Retrieve attachment (blob mode)")
    
    print("[  ] Delete attachment (blob mode) ")
    result = delete_attachment(db, result["id"], result["rev"], "test.png")
    @test result["ok"] == true
    println("\r[OK] Delete attachment (blob mode)")
  end
#end

Test.with_handler(test_handler) do
  print("[  ] alldocs: all ")
  result1 = alldocs(db; 
    descending    = true,
    endkey        = "",
    include_docs  = true,
    conflicts     = true,
    inclusive_end = true)
  @test result1["total_rows"] > 200
  println("\r[OK] alldocs: all")

  print("[  ] alldocs: limit & skip ")
  result2 = alldocs(db; 
    limit = 5,
    skip  = 2)
  @test length(result2["rows"]) == 5
  println("\r[OK] alldocs: limit & skip")

  print("[  ] alldocs: single key ")
  result3 = alldocs(db; key=result2["rows"][1]["key"])
  @test length(result3["rows"]) == 1
  println("\r[OK] alldocs: single key")

  print("[  ] alldocs: key set ")
  result4 = alldocs(db; keys=[result2["rows"][1]["key"], result2["rows"][2]["key"]])
  @test length(result4["rows"]) == 2
  println("\r[OK] alldocs: key set")

  print("[  ] alldocs: start & endkey ")
  result5 = alldocs(db; startkey=result2["rows"][1]["key"], endkey=result2["rows"][2]["key"])
  @test length(result5["rows"]) == 2
  println("\r[OK] alldocs: start & endkey")

  print("[  ] alldocs: start & endkey without inclusive_end ")
  result6 = alldocs(db; startkey=result2["rows"][1]["key"], endkey=result2["rows"][2]["key"], inclusive_end=false)
  @test length(result6["rows"]) == 1
  println("\r[OK] alldocs: start & endkey without inclusive_end")
end

Test.with_handler(test_handler) do
  print("[  ] Create a map view ")
  result = view_index(db, "my_ddoc", "my_view", 
  """
  function(doc) {
    if(doc && doc.name) {
      emit(doc.name, 1);
    }
  }""")
  @test result["ok"] == true
  println("\r[OK] Create a map view")

  print("[  ] Create a map-reduce view ")
  result = view_index(db, "my_ddoc2", "my_view2", 
  """
  function(doc) {
    if(doc && doc.data) {
      emit(doc.data, 1);
    }
  }"""; reduce="_stats")
  @test result["ok"] == true
  println("\r[OK] Create a map-reduce view")
  
  print("[  ] Query view ")
  result = view_query(db, "my_ddoc", "my_view"; include_docs=true, descending=true, conflicts=true, key="adam")
  @test length(result["rows"]) == 1
  println("\r[OK] Query view")
  
  print("[  ] Query view (POST) ")
  result = view_query(db, "my_ddoc", "my_view"; keys=["adam", "billy"])
  @test length(result["rows"]) == 2
  println("\r[OK] Query view (POST)")

  print("[  ] Query view (POST + skip) ")
  result = view_query(db, "my_ddoc", "my_view"; keys=["adam", "billy"], skip=1, limit=1)
  @test length(result["rows"]) == 1
  println("\r[OK] Query view (POST + skip)")

  print("[  ] Query view (startkey, endkey) ")
  result = view_query(db, "my_ddoc", "my_view"; startkey="adam", endkey="billy", inclusive_end=false)
  @test length(result["rows"]) == 1
  println("\r[OK] Query view (startkey, endkey)")

  print("[  ] Query view reduce ")
  result = view_query(db, "my_ddoc2", "my_view2"; key="adam", group=true, group_level=2)
  @test haskey(result, "rows")
  println("\r[OK] Query view reduce")

  print("[  ] Query view reduce off ")
  result = view_query(db, "my_ddoc2", "my_view2"; key="adam", reduce=false)
  @test haskey(result, "rows")
  println("\r[OK] Query view reduce off")
end

Test.with_handler(test_handler) do
  print("[  ] Retry settings ")
  retry_settings!(enabled=true)
  settings = retry_settings()
  @test settings["enabled"] == true
  println("\r[OK] Retry settings")

  print("[  ] 429 retry (MOCK) ")
  cl_mock = Client("blaha", "blaha", "http://mock429.eu-gb.mybluemix.net/"; auth=false)
  try
    db = createdb(cl_mock, database=database)
  catch err
    @test err.message == "max retries reached"
  end
  println("\r[OK] 429 retry (MOCK)")
end

Test.with_handler(test_handler) do
  print("[  ] Create a geospatial index ")
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

    print("[  ] Radius geospatial query with skip, legacy format and stale=true")
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

    print("[  ] Radius geospatial query with bookmark")
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

print("[  ] Delete test database: $database ")
result = deletedb(cl, database)
@test result["ok"] == true
println("\r[OK] Delete test database: $database")