#!/usr/bin/env julia

using Couchzilla
using Base.Test

username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST"]
database = "testdb"

cl = Couchzilla.Client(username, password, "https://$host")
db, result = Couchzilla.createdb(cl, database=database)

# write your own tests here
@test 1 == 1

