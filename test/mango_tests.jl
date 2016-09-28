@testset "Mango" begin
  print("\nMango tests\n[  ] Create a json Mango index ")
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
    
  result = createdoc(db, data)
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
  createdoc(db, [Dict("cust" => "john", "value" => "hello$x") for x=1:maxdoc])
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
  createdoc(db, [Dict("data" => "paged", "data2" => "world$x") for x=1:maxdoc])
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
