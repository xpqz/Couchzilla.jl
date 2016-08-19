# Implementation of the instance-level CouchDB CouchDB.

"""
    type Client
      url
      cookies

      Client(username::AbstractString, password::AbstractString, urlstr::AbstractString) = 
        cookieauth!(new(username, password, URI(urlstr)))
    end

The Client type represents an authenticated connection to a remote CouchDB/Cloudant instance.
"""
type Client
  url
  cookies

  Client(username::AbstractString, password::AbstractString, urlstr::AbstractString) = 
    cookieauth!(new(URI(urlstr)), username, password)
end

"""
    cookieauth!(client::Client, username, password) 

Private. Hits the `_session` endpoint to obtain a session cookie
that is used to authenticate subsequent requests.

[API reference](https://docs.cloudant.com/authentication.html#cookie-authentication)
"""
function cookieauth!(client::Client, username, password)
  response = post(endpoint(client.url, "_session"); 
    data=Dict("name" => username, "password" => password))
  client.cookies = cookies(response)
  client
end

"""
    db = connectdb(client::Client; database::AbstractString=nothing)

Return an immutable Database reference.

Subsequent database-level operations will operate on the chosen database. 
If you need to operate on a different database, you need to create a new 
Database reference. `connectdb(...)` does not check that the chosen remote 
database exists.
"""
function connectdb(client::Client; database::AbstractString=nothing) 
  Database(client, database)
end

"""
    db, created = createdb(client::Client; database::AbstractString=nothing)

Create a new database on the remote end called `dbname`. Return an immutable 
Database reference to this newly created db, and a boolean which is true if 
a database was created, false if it already existed.

[API reference](http://docs.couchdb.org/en/1.6.1/CouchDB/database/common.html#put--db)
"""
function createdb(client::Client; database::AbstractString=nothing)
  db = Database(client, database)
  created = false
  try 
    response = relax(put, string(db.url); cookies=client.cookies)
    created = true
  catch err
    # A 412 (db already exists) isn't always a fatal error. 
    # We bubble this up in the second returned value and leave
    # it to the user to decide.
    if !isa(err, HTTPException) || err.status != 412
      rethrow()
    end
  end
  return db, created
end

"""
    info = dbinfo(client::Client, name::AbstractString)

Return the meta data about the `dbname` database.

[API reference](http://docs.couchdb.org/en/1.6.1/CouchDB/database/common.html#get--db)
"""
function dbinfo(client::Client, name::AbstractString)
  relax(get, endpoint(client.url, name); cookies=client.cookies)
end

"""
    dblist = listdbs(client::Client)

Return a list of all databases under the authenticated user.

[API reference](http://docs.couchdb.org/en/1.6.1/CouchDB/server/common.html#all-dbs)
"""
function listdbs(client::Client)
  relax(get, endpoint(client.url, "_all_dbs"); cookies=client.cookies)
end

"""
    result = deletedb(client::Client, name::AbstractString)

Delete the named database.

[API reference](http://docs.couchdb.org/en/1.6.1/CouchDB/database/common.html?#delete--db)
"""
function deletedb(client::Client, name::AbstractString)
  relax(delete, endpoint(client.url, name); cookies=client.cookies)
end