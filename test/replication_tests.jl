@testset "Replication-related" begin
  print("\nReplication-related tests\n[  ] Streaming changes ")
  count = 0
  maxch = 5
  for ch in @task changes_streaming(db; limit=maxch)
    count += 1
  end
  @test count == maxch + 1 # In stream mode, last item is the CouchDB "last_seq" so need to add 1.
  println("\r[OK] Streaming changes")

  print("[  ] Static changes ")
  data = changes(db; limit=maxch, conflicts=true, include_docs=true, attachments=true, att_encoding_info=true)
  @test maxch == length(data["results"]) # In static mode, "last_seq" is a key in the dict.
  println("\r[OK] Static changes")

  print("[  ] Filtered changes ")
  data2 = changes(db; doc_ids=[data["results"][1]["id"], data["results"][2]["id"], data["results"][3]["id"]])
  @test length(data2["results"]) == 3 
  println("\r[OK] Filtered changes")

  print("[  ] Streaming changes, filtered ")
  count = 0
  for ch in @task changes_streaming(db; doc_ids=[data["results"][1]["id"], data["results"][2]["id"], data["results"][3]["id"]])
    count += 1
  end
  @test count > 0 
  println("\r[OK] Streaming changes, filtered")

  print("[  ] revs_diff ")
  fakerev = "2-1f0e2f0d841ba6b7e3d735b870ebeb8c"
  fakerevs = Dict(data["results"][1]["id"] => [data["results"][1]["changes"][1]["rev"], fakerev])
  diff = revs_diff(db; data=fakerevs)
  @test haskey(diff, data["results"][1]["id"])
  @test diff[data["results"][1]["id"]]["missing"][1] == fakerev
  println("\r[OK] revs_diff")

  print("[  ] bulk_get (note: needs CouchDB2 or Cloudant DBNext) ")
  fetchdata = [ 
    Dict{String, String}("id" => data["results"][1]["id"], "rev" => data["results"][1]["changes"][1]["rev"]),
  ]
  response = bulk_get(db; data=fetchdata)
  @test length(response["results"]) == 1
  println("\r[OK] bulk_get (note: needs CouchDB2 or Cloudant DBNext)")
end
