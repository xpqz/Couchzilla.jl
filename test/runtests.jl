#!/usr/bin/env julia

using Couchzilla
using Base.Test

username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST"]

database = "juliatest-$(Base.Random.uuid4())"
cl = Client(username, password, "https://$host")
db, created = createdb(cl, database=database)

test_handler(r::Test.Success) = nothing
function test_handler(r::Test.Failure)
  deletedb(cl, database)
  error("Test failed: $(r.expr)")
end

function test_handler(r::Test.Error)
  deletedb(cl, database)
  rethrow(r)
end

Test.with_handler(test_handler) do
  print("[  ] Create test database: $database")
  @test created == true
  println("\r[OK] Create test database: $database")
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

  print("[  ] Read new doc by {id, rev} (note: bad idea usually) ")
  doc = readdoc(db, data["id"]; rev=data["rev"])
  @test haskey(doc, "item")
  @test doc["item"] == "flange"
  println("\r[OK] Read new doc by {id, rev} (note: bad idea usually)")

  print("[  ] Reading doc by id and bad rev should fail ")
  @test_throws HTTPException readdoc(db, data["id"]; rev="3-63453748494907")
  println("\r[OK] Reading doc by id and bad rev should fail")
  
  print("[  ] Update existing doc ")
  doc = updatedoc(db; id=data["id"], rev=data["rev"], body=Dict("item" => "flange", "location" => "garage"))
  @test haskey(doc, "rev")
  @test contains(doc["rev"], "2-")
  println("\r[OK] Update existing doc")
end

Test.with_handler(test_handler) do
  print("[  ] Create a json Mango index ")
  result = createindex(db; fields=["data", "data2"])
  @test result["result"] == "created"
  println("\r[OK] Create a json Mango index")
  
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
  result = query(db, q"data = authenticate")
  @test length(result.docs) == 2
  println("\r[OK] Simple Mango query (equality)")
  
  print("[  ] Compound Mango query (and) ")
  result = query(db, and([q"data = world", q"data2 = vocabulary"]))
  @test length(result.docs) == 1
  @test result.docs[1]["name"] == "billy"
  println("\r[OK] Compound Mango query (and)")
  
  print("[  ] Compound Mango query (or) ")
  result = query(db, or([q"data = world", q"data2 = region"]))
  @test length(result.docs) == 3
  println("\r[OK] Compound Mango query (or)")
  
  print("[  ] Create a text Mango index ")
  result = createindex(db; fields=[
    Dict("name" => "cust",  "type" => "string"), 
    Dict("name" => "value", "type" => "string")
  ])
  @test result["result"] == "created"
  println("\r[OK] Create a text Mango index")
  
  maxdoc = 102
  createdoc(db; data=[Dict("cust" => "john", "value" => "hello$x") for x=1:maxdoc])
  print("[  ] Mango query with multi-page return ")
  result = query(db, q"cust=john")
  count = length(result.docs)
  while length(result.docs) > 0
    result = query(db, q"cust = john", bookmark=result.bookmark)
    count += length(result.docs)
  end
  @test count == maxdoc
  println("\r[OK] Mango query with multi-page return")
end

Test.with_handler(test_handler) do
  print("[  ] Upload attachment (blob mode) ")
  data = createdoc(db, Dict("item" => "screenshot"))
  result = put_attachment(db, data["id"], data["rev"], "test.png", "image/png", "data/test.png")
  @test result["ok"] == true
  println("\r[OK] Upload attachment (blob mode)")
  
  print("[  ] Retrieve attachment (blob mode) ")
  att = get_attachment(db, result["id"], "test.png"; rev=result["rev"])
  open("data/fetched.png", "w") do f
    write(f, att)
  end
  
  md5_fetched = chomp(readall(`md5 -q data/fetched.png`))
  md5_orig = chomp(readall(`md5 -q data/test.png`))
  @test md5_fetched == md5_orig
  rm("data/fetched.png")
  println("\r[OK] Retrieve attachment (blob mode)")
  
  print("[  ] Delete attachment (blob mode) ")
  result = delete_attachment(db, result["id"], result["rev"], "test.png")
  @test result["ok"] == true
  println("\r[OK] Delete attachment (blob mode)")
end

Test.with_handler(test_handler) do
  print("[  ] Create a view ")
  result = make_view(db, "my_ddoc", "my_view", 
  """
  function(doc) {
    if(doc && doc.name) {
      emit(doc.name, 1);
    }
  }""")
  @test result["ok"] == true
  println("\r[OK] Create a view")
  
  print("[  ] Query view ")
  result = query_view(db, "my_ddoc", "my_view"; include_docs=true, key="adam")
  @test length(result["rows"]) == 1
  println("\r[OK] Query view")
  
  print("[  ] Query view (POST)")
  result = query_view(db, "my_ddoc", "my_view"; keys=["adam", "billy"])
  @test length(result["rows"]) == 2
  println("\r[OK] Query view (POST)")
end

print("[  ] Delete test database: $database ")
result = deletedb(cl, database)
@test result["ok"] == true
println("\r[OK] Delete test database: $database")