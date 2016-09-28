@testset "Attachments" begin
  print("\nAttachment tests\n[  ] Upload attachment (blob mode) ")
  data = createdoc(db, Dict("item" => "screenshot"))
  result = put_attachment(db, data["id"], data["rev"], "test.png", "image/png", "../data/test.png")
  @test result["ok"] == true
  println("\r[OK] Upload attachment (blob mode)")
  
  print("[  ] Retrieve attachment (blob mode) ")
  att = get_attachment(db, result["id"], "test.png"; rev=result["rev"])
  open("../data/fetched.png", "w") do f
    write(f, att)
  end
 
  rm("../data/fetched.png")
  println("\r[OK] Retrieve attachment (blob mode)")
  
  print("[  ] Delete attachment (blob mode) ")
  result = delete_attachment(db, result["id"], result["rev"], "test.png")
  @test result["ok"] == true
  println("\r[OK] Delete attachment (blob mode)")
end
