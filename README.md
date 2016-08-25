# Couchzilla

[![Build Status](https://travis-ci.org/xpqz/Couchzilla.jl.svg?branch=master)](https://travis-ci.org/xpqz/Couchzilla.jl)

Couchzilla – CouchDB/Cloudant access for Julians.

Documentation can be found on [http://xpqz.github.io/couchzilla](http://xpqz.github.io/couchzilla)

The README here is a short extract from the main documentation; it may be out of date. 

## Getting Started

Couchzilla defines two types, `Client` and `Database`. `Client` represents an authenticated 
connection to the remote CouchDB _instance_. Using this you can perform database-level operations, 
such as creating, listing and deleting databases. The Database immutable type represents a client
that is connected to a specific database, allowing you to perform document-level operations.

Install the library using the normal Julia facilities `Pkg.add("Couchzilla")`.

Let's load up the credentials from environment variables.

     username = ENV["COUCH_USER"]
     password = ENV["COUCH_PASS"]
     host     = ENV["COUCH_HOST_URL"] # e.g. https://accountname.cloudant.com

We can now create a client connection:

    client = Client(username, password, host)

Using the client we can create a database:

    db, created = createdb(client; database="mynewdb")

If the database already existed, `created` will be set to `false` on return, and `true`
means that the database was created.

We can now add documents to the new database using `createdoc`:

    createdoc(db; data=[
        Dict("name"=>"adam", "data"=>"hello"),
        Dict("name"=>"billy", "data"=>"world"),
        Dict("name"=>"cecilia", "data"=>"authenticate"),
        Dict("name"=>"davina", "data"=>"cloudant"),
        Dict("name"=>"eric", "data"=>"blobbyblobbyblobby")
    ])

It returns an array of `Dict`s showing the `{id, rev}` tuples of the new documents:

    5-element Array{Any,1}:
     Dict{UTF8String,Any}("ok"=>true,"rev"=>"1-783f91178091c10cce61c326473e8849","id"=>"6163490e3753b6461cd212ec1e496b56")
     Dict{UTF8String,Any}("ok"=>true,"rev"=>"1-9ecba7e9a824a6fdcfb005c454fea12e","id"=>"6163490e3753b6461cd212ec1e496fb0")
     Dict{UTF8String,Any}("ok"=>true,"rev"=>"1-e05530fc65101ed432c5ee457d327952","id"=>"6163490e3753b6461cd212ec1e497092")
     Dict{UTF8String,Any}("ok"=>true,"rev"=>"1-446bb325003aa6a995bde4e7c3dd513f","id"=>"6163490e3753b6461cd212ec1e497f8f")
     Dict{UTF8String,Any}("ok"=>true,"rev"=>"1-e1f2181b3b4d7fa285b4516eee02d287","id"=>"6163490e3753b6461cd212ec1e4984e2")

This form of `createdoc` creates multiple documents using a single `HTTP POST` which is 
the most efficient way of creating multiple new documents.

We can read a document back using `readdoc`, hitting the CouchDB primary index:

    readdoc(db, "6163490e3753b6461cd212ec1e496b56")

which returns the winning revision for the given `id` as a `Dict`:

    Dict{UTF8String,Any} with 4 entries:
      "_id"  => "6163490e3753b6461cd212ec1e496b56"
      "_rev" => "1-783f91178091c10cce61c326473e8849"
      "name" => "adam"
      "data" => "hello"

In order to use the new Mango/Cloudant Query language to interact with the database
we first need to create an index:

    mango_index(db; fields=["name", "data"])

    Dict{UTF8String,Any} with 3 entries:
      "name"   => "f519be04f7f80838b6a88811f75de4fb83d966dd"
      "id"     => "_design/f519be04f7f80838b6a88811f75de4fb83d966dd"
      "result" => "created"

We can now use this index to retrieve data:

    mango_query(db, q"name=davina")

    Couchzilla.QueryResult([Dict{AbstractString,Any}(
      "_rev"=>"1-4..3f",
      "name"=>"davina",
      "_id"=>"616..f8f",
      "data"=>"cloudant")],"")

The construct `r"..."` is a custom string literal type which takes a simplistic DSL 
expression which gets converted to the actual JSON-representation of a Mango selector.
If you are familiar with Mango selectors, you can use the raw JSON expression if you
prefer:

    mango_query(db, Selector("{\"name\":{\"\$eq\":\"davina\"}}"))

You can also create secondary indexes, known as `views`. They are created
using a map function written in Javascript. For example, to create a view
on the `name` field, we could use the following:

    view_index(db, "my_ddoc", "my_view", 
    """
    function(doc) {
      if(doc && doc.name) {
        emit(doc.name, 1);
      }
    }""")

    Dict{UTF8String,Any} with 3 entries:
      "ok"  => true
      "rev" => "1-b950984b19bb1b8bb43513c9d5b235bc"
      "id"  => "_design/my_ddoc

To read from this view, use the `query_view` method:

    view_query(db, "my_ddoc", "my_view"; keys=["davina", "billy"])

    Dict{UTF8String,Any} with 3 entries:
      "rows"       => Any[Dict{UTF8String,Any}("key"=>"davina","id"=>...)
      "offset"     => 1
      "total_rows" => 5

