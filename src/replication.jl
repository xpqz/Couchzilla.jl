# The CouchDB replication API

function opts(;
  doc_ids = [],
  conflicts = false,
  descending = false,
  include_docs = false,
  attachments = false,
  att_encoding_info = false,
  last_event_id = 0,
  limit = 0,
  feed = "normal",
  timeout = -1,
  since = "")

  query = Dict{UTF8String, Any}()
  if length(doc_ids) > 0
    query["doc_ids"] = doc_ids
  end
  if conflicts && include_docs # conflicts only relevant if include_docs is true
    query["conflicts"] = true
  end
  if include_docs
    query["include_docs"] = true
  end
  if attachments
    query["attachments"] = true
  end
  if att_encoding_info
    query["att_encoding_info"] = true
  end
  if last_event_id != 0
    query["last-event-id"] = last_event_id
  end
  if since != ""
    query["since"] = since
  end
  if limit > 0
    query["limit"] = limit
  end
  if feed != "normal"
    query["feed"] = feed
  end
  if (feed == "continuous" || feed == "longpoll") && timeout != -1
    query["timeout"] = timeout
  end

  query
end

"""
    changes_streaming(db::Database;
      doc_ids = [],
      conflicts = false,
      descending = false,
      include_docs = false,
      attachments = false,
      att_encoding_info = false,
      last-event-id = 0,
      limit = 0
      since = 0)

Query the CouchDB changes feed, line by line. This is a co-routine. 
Note that the last item produced will always  be the CouchDB `last_seq` 
entry.

This is a co-routine. Filtering options not supported.

### Examples

    for ch in @task changes_streaming(db, limit=1)
      println(ch)
    end

    Dict(
      "seq"=>"1-g1...gm-",
      "changes"=>[Dict("rev"=>"1-24213171b98945a2ed3578c926eb3651")], 
      "id"=>"37f11227ef384458b01e4afc7eed7194"
    )
    Dict(
      "pending"=>213,
      "last_seq"=>"1-g1...gm-"
    )

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/changes.html)
"""
function changes_streaming(db::Database;
  doc_ids = [],
  conflicts = false,
  descending = false,
  include_docs = false,
  attachments = false,
  att_encoding_info = false,
  last_event_id = 0,
  limit = 0,
  since = 0)

  query = opts(doc_ids=doc_ids, conflicts=conflicts, descending=descending, 
    include_docs=include_docs, attachments=attachments, att_encoding_info=att_encoding_info,
    last_event_id=last_event_id, limit=limit, since=since, feed="continuous", timeout=0)

  stream = Requests.get_streaming(endpoint(db.url, "_changes"); cookies=db.client.cookies, query=query)
  while true
    line = strip(readline(stream))
    if length(line) > 0 && line[1] == '{'
      produce(JSON.parse(line))
    end
    if eof(stream)
      break
    end
  end
end

"""
    changes(db::Database;
      doc_ids = [],
      conflicts = false,
      descending = false,
      include_docs = false,
      attachments = false,
      att_encoding_info = false,
      last-event-id = 0,
      limit = 0
      since = 0)

Query the CouchDB changes feed, returned as a big `Dict`. Normal mode only. Filtering options not
supported.

### Examples

    results = changes(db; include_docs=true, since=0)

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/changes.html)
"""
function changes(db::Database;
  doc_ids = [],
  conflicts = false,
  descending = false,
  include_docs = false,
  attachments = false,
  att_encoding_info = false,
  last_event_id = 0,
  limit = 0,
  since = 0)

  query = opts(doc_ids=doc_ids, conflicts=conflicts, descending=descending, 
    include_docs=include_docs, attachments=attachments, att_encoding_info=att_encoding_info,
    last_event_id=last_event_id, limit=limit, since=since)

  relax(get, endpoint(db.url, "_changes"); cookies=db.client.cookies, query=query)
end

"""
    revs_diff{T<:AbstractString}(db::Database; data::Dict{T, Vector{T}} = Dict())

`revs_diff` is a component of the CouchDB replication algorithm.

Given set of ids and revs, it will return a potentially empty subset
of ids and revs from this list which the remote end doesn't have.

    Dict(
        "190f721ca3411be7aa9477db5f948bbb" => [
            "3-bb72a7682290f94a985f7afac8b27137",
            "4-10265e5a26d807a3cfa459cf1a82ef2e",
            "5-067a00dff5e02add41819138abb3284d"
        ]
    )

### Returns

The returned structure is a `Dict` where the keys are the `id`s of any documents
where missing `rev`s are found. An example:

    Dict(
      "e1132d11a43933948cb46c5e72e13659" => Dict(
        "missing" => ["2-1f0e2f0d841ba6b7e3d735b870ebeb8c"],
        "possible_ancestors" => ["1-efda16b0115e5fcf2cfd065faee674fc"]
      )
    )

[API reference](http://docs.couchdb.org/en/1.6.1/api/database/misc.html#db-revs-diff)
"""
function revs_diff{T<:AbstractString}(db::Database; data::Dict{T, Vector{T}} = Dict())
  relax(post, endpoint(db.url, "_revs_diff"); json=data, cookies=db.client.cookies)
end

"""
    bulk_get{T<:AbstractString}(db::Database; data::Vector{Dict{T, T}} = [])

`bulk_get` is used as part of an optimisation of the CouchDB replication algorithm in 
recent versions, allowing the replicator to request many documents with full
ancestral information in a singe HTTP request.

It is supported in CouchDB >= 2.0 (Cloudant "DBNext"), and also suported by PouchDB.

The `data` parameter is a list of `Dict`s with keys `id` and `rev`.

### Examples

    result = revs_diff(db; data = [
      Dict(
        "id"  => "f6b40e2fdc017e7e4ec4fa88ae3a4950", 
        "rev" => "2-1f0e2f0d841ba6b7e3d735b870ebeb8c"
      ),
      Dict(
        "id"  => "2f8b7921cbcfde79fb2ff8079cada273", 
        "rev" => "1-6c3ef2ba29b6631a01ce00f80b5b4ad3"
      )    
    ])

### Returns

The response format is convoluted, and seemingly undocumented for both CouchDB and
Cloudant at the time of writing.

    "results": [
    {
      "id": "1c43dd76fee5036c0cb360648301a710",
      "docs": [
        {
          "ok": { ..doc body here...

            }
          }
        }
      ]
    },

[Reference](https://issues.apache.org/jira/browse/COUCHDB-2310)
"""
function bulk_get{T<:AbstractString}(db::Database; data::Vector{Dict{T, T}} = [])
  relax(post, endpoint(db.url, "_bulk_get"); json=Dict("docs" => data), cookies=db.client.cookies)
end