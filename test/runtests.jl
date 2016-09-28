#!/usr/bin/env julia

using Couchzilla
using Base.Test

username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST_URL"]

geo_database = ""
if haskey(ENV, "COUCH_GEO_DATABASE")
  geo_database = ENV["COUCH_GEO_DATABASE"]
end

database = "juliatest-$(Base.Random.uuid4())"
geo_database = "crimes"
cl = Client(username, password, host)
db, created = createdb(cl; database=database)

try
  include("db_meta_tests.jl")
  include("crud_tests.jl")
  include("mango_tests.jl")
  include("replication_tests.jl")
  include("attachment_tests.jl")  
  include("alldocs_tests.jl")    
  include("view_tests.jl")      
  include("retry_tests.jl")        
  include("geo_tests.jl")          
  include("apikey_tests.jl")            

  # Include new tests above this line
  include("delete_db_tests.jl")
catch TestSetException
  println("\n[INFO] Deleting test database on failure")
  deletedb(cl, database)
end

