@testset "Meta" begin
  println(testname("Meta tests"))
  print("  [  ] DBInfo ")
  result = dbinfo(cl, database)
  @test result["doc_count"] == 0
  println("\r  [OK] DBInfo")

  print("  [  ] List dbs ")
  result = listdbs(cl)
  @test database ∈ result
  println("\r  [OK] List dbs")
end
