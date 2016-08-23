```@meta
CurrentModule = Couchzilla
```

# Couchzilla
 
Couchzilla – CouchDB/Cloudant access for Julians.

## Philosophy

We've tried to wrap the CouchDB API as thinly as possible, hiding the JSON and the HTTP but no 
overwrought abstractions on top. That means that a CouchDB JSON document is represented as the 
corresponding de-serialisation into native Julia types:

    {
      "_id": "45c4affe6f40c7aaf0ba533f7a6601a2",
      "_rev": "1-47e8deed9ccfcf8d061f7721d3ba085c",
      "item": "Malus domestica",
      "prices": {
        "Fresh Mart": 1.59,
        "Price Max": 5.99,
        "Apples Express": 0.79
      }
    }

is represented as 

    Dict{UTF8String,Any}(
      "_rev"   => "1-47e8deed9ccfcf8d061f7721d3ba085c",
      "prices" => Dict{UTF8String,Any}("Fresh Mart"=>1.59,"Price Max"=>5.99,"Apples Express"=>0.79),
      "_id"    => "45c4affe6f40c7aaf0ba533f7a6601a2",
      "item"   => "Malus domestica"
    )

Along similar lines, Couchzilla will return CouchDB's JSON-responses simply converted as-is.

## Getting Started

Couchzilla defines two types, [`Client`](@ref) and [`Database`](@ref). `Client` represents an authenticated 
connection to the remote CouchDB _instance_. Using this you can perform database-level operations, 
such as creating, listing and deleting databases. The Database immutable type represents a client
that is connected to a specific database, allowing you to perform document-level operations.

Install the library using the normal Julia facilities `Pkg.add("Couchzilla")`.

Let's load up the credentials from environment variables.

```@example intro
using Couchzilla # hide
importall Couchzilla # hide
username = ENV["COUCH_USER"]
password = ENV["COUCH_PASS"]
host     = ENV["COUCH_HOST_URL"] # e.g. https://accountname.cloudant.com
nothing; # hide
```

We can now create a client connection, and use that to create a new database:

```@example intro
dbname = "mynewdb"
client = Client(username, password, host)
db, created = createdb(client; database=dbname)
nothing; # hide
```

If the database already existed, `created` will be set to `false` on return, and `true`
means that the database was created.

We can now add documents to the new database using [`createdoc`](@ref). It returns an array of 
`Dict`s showing the `{id, rev}` tuples of the new documents:

```@example intro
result = createdoc(db; data=[
    Dict("name" => "adam",    "data" => "hello"),
    Dict("name" => "billy",   "data" => "world"),
    Dict("name" => "cecilia", "data" => "authenticate"),
    Dict("name" => "davina",  "data" => "cloudant"),
    Dict("name" => "eric",    "data" => "blobbyblobbyblobby")
])
```

This form of [`createdoc`](@ref) creates multiple documents using a single `HTTP POST` which is 
the most efficient way of creating multiple new documents.

We can read a document back using [`readdoc`](@ref), hitting the CouchDB primary index. Note that 
reading back a document you just created is normally bad practice, as it will sooner or 
later fall foul of CouchDB's [eventual consistency](http://guide.couchdb.org/draft/consistency.html) 
and give rise to sporadic, hard to troubleshoot errors. Having said that, let's do it 
anyway, and hope for the best:

```@example intro
id = result[2]["id"]
readdoc(db, id)
```

returning the winning revision for the given `id` as a `Dict`.

[Conflict handling](http://guide.couchdb.org/draft/conflicts.html) in CouchDB and eventual 
consistency is beyond the scope of this documentation, but worth understanding fully before using 
CouchDB in anger.

## Query

`Mango` (also known as [Cloudant Query](https://docs.cloudant.com/cloudant_query.html)) is 
a declarative query language inspired by [MongoDB](https://docs.mongodb.com/). It allows
us to query the database in a (slightly) more ad-hoc fashion than using map reduce views.

In order to use this feature we first need to set up the necessary indexes:

```@example intro
createindex(db; fields=["name", "data"])
```

We can now use this index to retrieve data:

```@example intro
query(db, q"name=davina")
```
 
The construct `q"..."` (see [`@q_str`](@ref)) is a custom string literal type which takes a simplistic DSL 
expression which gets converted to the actual JSON-representation of a Mango selector.
If you are familiar with [Mango selectors](https://docs.cloudant.com/cloudant_query.html#selector-syntax), 
you can use the raw JSON expression if you prefer:

```@example intro
query(db, Selector("{\"name\":{\"\$eq\":\"davina\"}}"))
```

There are also coroutine versions of some of the functions that return data
from views. If we had many results to process, we could use [`paged_query`](@ref)
in a Julia Task:

    for page in @task paged_query(db, q"name=davina"; pagesize=10)
        # Do something with the page.docs array
    end

This version uses the `limit` and `skip` parameters and issues an HTTP(S) request
per page.

## Views

A powerful feature of CouchDB are [secondary indexes](http://docs.couchdb.org/en/1.6.1/couchapp/views/intro.html), 
known as [views](http://guide.couchdb.org/draft/views.html). They are created using 
a map function written most commonly in Javascript, and optionally a reduce part. For 
example, to create a view on the `name` field, we use the following:

```@example intro
make_view(db, "my_ddoc", "my_view", 
"""
function(doc) {
  if(doc && doc.name) {
    emit(doc.name, 1);
  }
}""")
```

To read from this view, use the [`query_view`](@ref) method:

```@example intro
query_view(db, "my_ddoc", "my_view"; keys=["davina", "billy"])
```

## Using attachments

CouchDB can store files alongside documents as attachments. This can be a convenient feature
for many applications, but it has drawbacks, especially in terms of performance. If you find
that you need to store large (say greater than a couple of meg) binary attachments, you should
probably consider a dedicated, separate file store and only use CouchDB for metadata.

To write an attachment, use [`put_attachment`](@ref), which expects an `{id, rev}` tuple referencing
and existing document in the database and the path to the file holding the attachment:

    data = createdoc(db, Dict("item" => "screenshot"))
    result = put_attachment(db, data["id"], data["rev"], "test.png", "image/png", "data/test.png")

In order to read the attachment, use [`get_attachment`](@ref), which returns an IO stream:

    att = get_attachment(db, result["id"], "test.png"; rev=result["rev"])
    open("data/fetched.png", "w") do f
      write(f, att)
    end

If you want to delete a database, simply call [`deletedb`](@ref):

```@example intro
deletedb(client, dbname)
```

## Client

```@docs
Couchzilla.Client
Couchzilla.connectdb(client::Client; database::AbstractString=nothing)
Couchzilla.createdb(client::Client; database::AbstractString=nothing)
Couchzilla.dbinfo(client::Client, name::AbstractString)
Couchzilla.listdbs(client::Client)
Couchzilla.deletedb(client::Client, name::AbstractString)
Couchzilla.cookieauth!
```

## Database

The Database type represents a client connection tied to a specific database name. This is 
immutable, meaning that if you need to talk to several databases you need to create one Database
type for each.

```@docs
Couchzilla.Database
Couchzilla.bulkdocs(db::Database; data=[], options=Dict())
Couchzilla.createdoc(db::Database, body=Dict())
Couchzilla.createdoc(db::Database; data=[Dict()])
Couchzilla.readdoc(db::Database,id::AbstractString;rev="",attachments=false,att_encoding_info=false,atts_since=[],conflicts= false,deleted_conflicts=false,latest=false,meta=false,open_revs=[],revs=false,revs_info=false)
Couchzilla.updatedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing, body=Dict())
Couchzilla.deletedoc(db::Database; id::AbstractString=nothing, rev::AbstractString=nothing)
```

## Views
```@docs
Couchzilla.make_view(db::Database, ddoc::AbstractString, name::AbstractString, map::AbstractString; reduce::AbstractString = "")
Couchzilla.query_view
Couchzilla.alldocs
```

## Mango/Cloudant Query
```@docs
Couchzilla.Selector
Couchzilla.Selector()
Couchzilla.Selector(raw_json::AbstractString)
Couchzilla.isempty
Couchzilla.@q_str
Couchzilla.QueryResult
Couchzilla.query
Couchzilla.paged_query
Couchzilla.createindex
Couchzilla.listindexes(db::Database)
Couchzilla.deleteindex(db::Database; ddoc="", name="", indextype="")
```

## Attachments

You can attach files to documents in CouchDB. This can occasionally be convenient,
but using attachments has performance implications, especially when combined with 
replication. See Cloudant's [docs](https://docs.cloudant.com/attachments.html) on 
the subject.

```@docs
Couchzilla.put_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString, mimetype::AbstractString, file::AbstractString)
Couchzilla.get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
Couchzilla.delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
```

## Replication

Unlike e.g. [PouchDB](https://pouchdb.com/), [CDTDatastore](https://github.com/cloudant/CDTDatastore) 
and [sync-android](https://github.com/cloudant/sync-android), `Couchzilla` is not a replication library 
in that it does not implement a local data store. However, you have access to all replication-related
endpoints provided by CouchDB. The CouchDB replication algorithm is largely undocumented, but a good
[write-up](https://github.com/couchbase/couchbase-lite-ios/wiki/Replication-Algorithm) can be found 
in Couchbase's repo.

```@docs
Couchzilla.changes
Couchzilla.changes_streaming
Couchzilla.revs_diff
Couchzilla.bulk_get
```

## Geospatial

```@docs
Couchzilla.geo_index
Couchzilla.geo_index_info
Couchzilla.geo_query
```

## Utility stuff
```@docs
Couchzilla.relax
Couchzilla.endpoint
```