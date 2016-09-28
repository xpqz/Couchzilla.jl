@testset "Delete DB" begin
  print("\nDelete DB tests\n[  ] Delete test database: $database ")
  result = deletedb(cl, database)
  @test result["ok"] == true
  println("\r[OK] Delete test database: $database")
end
