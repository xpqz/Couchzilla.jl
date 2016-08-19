```@meta
CurrentModule = Couchzilla
```

# Couchzilla
 
Couchzilla is a client library for CouchDB (and Cloudant).

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
Couchzilla.createindex
Couchzilla.listindexes(db::Database)
deleteindex(db::Database; ddoc="", name="", indextype="")
```

## Attachments
```@docs
Couchzilla.put_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString, mimetype::AbstractString, file::AbstractString)
Couchzilla.get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
Couchzilla.delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
```

## Utility stuff
```@docs
Couchzilla.relax
Couchzilla.endpoint
```