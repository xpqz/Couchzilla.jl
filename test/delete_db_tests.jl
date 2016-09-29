@testset "Delete DB" begin
  println(testname("Delete DB tests"))
  print("  [  ] Delete test database: $database ")
  result = deletedb(cl, database)
  @test result["ok"] == true
  println("\r  [OK] Delete test database: $database")
end
