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
  print("[  ] Create a json CQ index ")
  result = createindex(db; fields=["name", "data"])
  @test result["result"] == "created"
  println("\r[OK] Create a json CQ index")
end

Test.with_handler(test_handler) do
  print("[  ] Bulk load data ")
  result = createdoc(db; data=[
    Dict("name"=>"adam",    "data"=>"hello"),
    Dict("name"=>"billy",   "data"=>"world"),
    Dict("name"=>"bob",     "data"=>"world"),
    Dict("name"=>"cecilia", "data"=>"authenticate"),
    Dict("name"=>"davina",  "data"=>"cloudant"),
    Dict("name"=>"eric",    "data"=>"blobbyblobbyblobby")
  ])
  @test length(result) == 6
  println("\r[OK] Bulk load data")
end

Test.with_handler(test_handler) do
  print("[  ] Simple CQ query (equality) ")
  result = query(db, q"name = billy")
  @test length(result.docs) == 1
  @test result.docs[1]["data"] == "world"
  @test result.bookmark == ""
  println("\r[OK] Simple CQ query (equality)")
  
  print("[  ] Compound CQ query (and) ")
  result = query(db, and([q"data = world", q"name = bob"]))
  @test length(result.docs) == 1
  @test result.docs[1]["name"] == "bob"
  @test result.bookmark == ""
  println("\r[OK] Compound CQ query (and)")
  
  print("[  ] Compound CQ query (or) ")
  result = query(db, or([q"data = world", q"data = cloudant"]))
  @test length(result.docs) == 3
  @test result.bookmark == ""
  println("\r[OK] Compound CQ query (or)")
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

print("[  ] Delete test database: $database ")
result = deletedb(cl, database)
@test result["ok"] == true
println("\r\r[OK] Delete test database: $database")