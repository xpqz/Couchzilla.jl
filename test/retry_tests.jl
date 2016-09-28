@testset "Retry 429" begin
  print("\nRetry on 429 tests\n[  ] Retry settings ")
  retry_settings!(enabled=true)
  settings = retry_settings()
  @test settings["enabled"] == true
  println("\r[OK] Retry settings")

  print("[  ] 429 retry (MOCK) ")
  cl_mock = Client("blaha", "blaha", "http://mock429.eu-gb.mybluemix.net/"; auth=false)
  try
    db = createdb(cl_mock, database=database)
  catch err
    @test err.message == "max retries reached"
  end
  println("\r[OK] 429 retry (MOCK)")
end
