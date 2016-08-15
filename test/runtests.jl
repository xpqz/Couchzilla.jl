#!/usr/bin/env julia

using Couchzilla
using Base.Test

username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST"]

database = "juliatest-$(Base.Random.uuid4())"

println("Test database: $database")

cl = Client(username, password, "https://$host")
db, created = createdb(cl, database=database)
@test created == true # Only prepared to run these tests if the database is fresh

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
  print("Check that reading a non-existing id fails ")
  @test_throws HTTPException readdoc(db, "this-id-does-not-exist")
  println("[OK]")
end

Test.with_handler(test_handler) do
  print("Check create document ")
  data = createdoc(db, Dict("item" => "flange", "location" => "under-stairs cupboard"))
  @test haskey(data, "id")
  @test haskey(data, "rev")
  println("[OK]")

  print("Check reading just created document by id and rev (note: bad idea usually) ")
  doc = readdoc(db, data["id"]; rev=data["rev"])
  @test haskey(doc, "item")
  @test doc["item"] == "flange"
  println("[OK]")

  print("Check reading just created document by id and bad rev ")
  @test_throws HTTPException readdoc(db, data["id"]; rev="3-63453748494907")
  println("[OK]")
  
  print("Update existing document ")
  doc = updatedoc(db; id=data["id"], rev=data["rev"], body=Dict("item" => "flange", "location" => "garage"))
  @test haskey(doc, "rev")
  @test contains(doc["rev"], "2-")
  println("[OK]")
end

Test.with_handler(test_handler) do
  print("Create a json CQ index ")
  result = createindex(db; fields=["name", "data"])
  @test result["result"] == "created"
  println("[OK]")
end

Test.with_handler(test_handler) do
  print("Bulk load data ")
  result = createdoc(db; data=[
    Dict("name"=>"adam",    "data"=>"hello"),
    Dict("name"=>"billy",   "data"=>"world"),
    Dict("name"=>"bob",     "data"=>"world"),
    Dict("name"=>"cecilia", "data"=>"authenticate"),
    Dict("name"=>"davina",  "data"=>"cloudant"),
    Dict("name"=>"eric",    "data"=>"blobbyblobbyblobby")
  ])
  @test length(result) == 6
  println("[OK]")
end

Test.with_handler(test_handler) do
  print("Simple CQ query (equality) ")
  result = query(db, q"name = billy")
  @test length(result.docs) == 1
  @test result.docs[1]["data"] == "world"
  @test result.bookmark == ""
  println("[OK]")
  
  print("Compound CQ query (and) ")
  result = query(db, and([q"data = world", q"name = bob"]))
  @test length(result.docs) == 1
  @test result.docs[1]["name"] == "bob"
  @test result.bookmark == ""
  println("[OK]")
  
  print("Compound CQ query (or) ")
  result = query(db, or([q"data = world", q"data = cloudant"]))
  @test length(result.docs) == 3
  @test result.bookmark == ""
  println("[OK]")
end

println("Delete test database: $database")
result = deletedb(cl, database)
@test result["ok"] == true