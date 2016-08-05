#!/usr/bin/env julia

using Couchzilla
using Base.Test

username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST"]
database = "testdb2"

cl = Couchzilla.Client(username, password, "https://$host")
db, created = Couchzilla.createdb(cl, database=database)

# write your own tests here
@test 1 == 1

print("Check that reading a non-existing id fails ")
@test_throws HTTPException Couchzilla.read(db, "this-id-does-not-exist")
println("[OK]")

print("Check create document ")
data = Couchzilla.create(db; body=Dict("item" => "flange", "location" => "under-stairs cupboard"))

@test haskey(data, "id")
@test haskey(data, "rev")
println("[OK]")

print("Check reading just created document by id and rev (note: bad idea usually) ")
doc = Couchzilla.read(db, data["id"]; rev=data["rev"])
@test haskey(doc, "item")
@test doc["item"] == "flange"
println("[OK]")

print("Check reading just created document by id and bad rev ")
@test_throws HTTPException Couchzilla.read(db, data["id"]; rev="3-63453748494907")
println("[OK]")

print("Update an existing document ")
doc = Couchzilla.update(db; id=data["id"], rev=data["rev"], body=Dict("item" => "flange", "location" => "garage"))
@test haskey(doc, "rev")
@test contains(doc["rev"], "2-")
println("[OK]")