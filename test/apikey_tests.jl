@testset "API keys" begin
  println(testname("API key tests"))
  print("  [  ] Make api key ")
  result = make_api_key(cl)
  @test result["ok"] == true
  println("\r  [OK] Make api key")

  api_key = result["key"]

  print("  [  ] Set permissions ")
  result = set_permissions(db; key=api_key, roles=["_reader", "_writer"])
  @test result["ok"] == true
  println("\r  [OK] Set permissions")

  print("  [  ] Set permissions with no permissions should fail ")
  @test_throws ErrorException set_permissions(db)
  println("\r  [OK] Set permissions with no permissions should fail")

  print("  [  ] Set permissions with no roles should fail ")
  @test_throws ErrorException set_permissions(db; key=api_key)
  println("\r  [OK] Set permissions with no roles should fail")

  print("  [  ] View permissions ")
  permissions = get_permissions(db)
  @test haskey(permissions, "cloudant") && haskey(permissions["cloudant"], api_key)
  println("\r  [OK] View permissions")

  print("  [  ] Modify existing permissions ")
  result = set_permissions(db, permissions; key=api_key, roles=["_reader"])
  @test result["ok"] == true
  println("\r  [OK] Modify existing permissions")

  print("  [  ] Delete API key ")
  @test delete_api_key(db, api_key)
  println("\r  [OK] Delete API key")

   print("  [  ] Delete non-existing API key ")
  @test delete_api_key(db, "NOSUCHKEY") == false
  println("\r  [OK] Delete non-existing API key")
end
