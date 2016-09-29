@testset "Views" begin
  println(testname("View tests"))
  print("  [  ] Create a map view ")
  result = view_index(db, "my_ddoc", "my_view", 
  """
  function(doc) {
    if(doc && doc.name) {
      emit(doc.name, 1);
    }
  }""")
  @test result["ok"] == true
  println("\r  [OK] Create a map view")

  print("  [  ] Create a map-reduce view ")
  result = view_index(db, "my_ddoc2", "my_view2", 
  """
  function(doc) {
    if(doc && doc.data) {
      emit(doc.data, 1);
    }
  }"""; reduce="_stats")
  @test result["ok"] == true
  println("\r  [OK] Create a map-reduce view")
  
  print("  [  ] Query view ")
  result = view_query(db, "my_ddoc", "my_view"; include_docs=true, descending=true, conflicts=true, key="adam")
  @test length(result["rows"]) == 1
  println("\r  [OK] Query view")
  
  print("  [  ] Query view (POST) ")
  result = view_query(db, "my_ddoc", "my_view"; keys=["adam", "billy"])
  @test length(result["rows"]) == 2
  println("\r  [OK] Query view (POST)")

  print("  [  ] Query view (POST + skip) ")
  result = view_query(db, "my_ddoc", "my_view"; keys=["adam", "billy"], skip=1, limit=1)
  @test length(result["rows"]) == 1
  println("\r  [OK] Query view (POST + skip)")

  print("  [  ] Query view (startkey, endkey) ")
  result = view_query(db, "my_ddoc", "my_view"; startkey="adam", endkey="billy", inclusive_end=false)
  @test length(result["rows"]) == 1
  println("\r  [OK] Query view (startkey, endkey)")

  print("  [  ] Query view reduce ")
  result = view_query(db, "my_ddoc2", "my_view2"; key="adam", group=true, group_level=2)
  @test haskey(result, "rows")
  println("\r  [OK] Query view reduce")

  print("  [  ] Query view reduce off ")
  result = view_query(db, "my_ddoc2", "my_view2"; key="adam", reduce=false)
  @test haskey(result, "rows")
  println("\r  [OK] Query view reduce off")
end
