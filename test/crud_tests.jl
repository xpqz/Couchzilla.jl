@testset "CRUD" begin
  print("\nCRUD tests\n[  ] Read a non-existing id ")
  @test_throws HTTPException readdoc(db, "this-id-does-not-exist")
  println("\r[OK] Read a non-existing id")

  print("[  ] Create new doc ")
  data = createdoc(db, Dict("item" => "flange", "location" => "under-stairs cupboard"))
  @test haskey(data, "id")
  @test haskey(data, "rev")
  println("\r[OK] Create new doc")

  print("[  ] Create new doc with empty body should fail ")
  @test_throws ErrorException createdoc(db, Dict())
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
