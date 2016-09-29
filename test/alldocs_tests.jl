@testset "Alldocs" begin
  println(testname("Alldocs tests"))
  print("  [  ] alldocs: all ")
  result1 = alldocs(db; 
    descending    = true,
    endkey        = "",
    include_docs  = true,
    conflicts     = true,
    inclusive_end = true)
  @test result1["total_rows"] > 200
  println("\r  [OK] alldocs: all")

  print("  [  ] alldocs: limit & skip ")
  result2 = alldocs(db; 
    limit = 5,
    skip  = 2)
  @test length(result2["rows"]) == 5
  println("\r  [OK] alldocs: limit & skip")

  print("  [  ] alldocs: single key ")
  result3 = alldocs(db; key=result2["rows"][1]["key"])
  @test length(result3["rows"]) == 1
  println("\r  [OK] alldocs: single key")

  print("  [  ] alldocs: key set ")
  result4 = alldocs(db; keys=[result2["rows"][1]["key"], result2["rows"][2]["key"]])
  @test length(result4["rows"]) == 2
  println("\r  [OK] alldocs: key set")

  print("  [  ] alldocs: start & endkey ")
  result5 = alldocs(db; startkey=result2["rows"][1]["key"], endkey=result2["rows"][2]["key"])
  @test length(result5["rows"]) == 2
  println("\r  [OK] alldocs: start & endkey")

  print("  [  ] alldocs: start & endkey without inclusive_end ")
  result6 = alldocs(db; startkey=result2["rows"][1]["key"], endkey=result2["rows"][2]["key"], inclusive_end=false)
  @test length(result6["rows"]) == 1
  println("\r  [OK] alldocs: start & endkey without inclusive_end")
end
