__precompile__()

"""
The CouchDB API.


"""
module Couchzilla

using Requests
using URIParser
using JSON

import Requests: get, post, put, delete, requestfor, headers

include("utils.jl")
include("client.jl")
include("database.jl")
include("selector.jl")
include("mango.jl")
include("attachments.jl")
include("replication.jl")
include("views.jl")

export Client, Database, HTTPException, QueryResult, Selector, @q_str
export createdb, connect, dbinfo, listdbs, deletedb, createdoc, readdoc
export updatedoc, deletedoc, alldocs, changes, query, createindex
export and, or, nor, not, put_attachment, get_attachment, delete_attachment
export make_view, query_view, listindexes, deleteindex

end # module