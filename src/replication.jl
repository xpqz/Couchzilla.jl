# The CouchDB replication API

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
      since = "")

Query the CouchDB changes feed. This is a co-routine. The generated request 
will stream, but only normal feed style supported. Filtering options not
supported.

### Examples

    for ch in @task changes(db, include_docs=true, conflicts=true)

    end

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

  println(query)
  stream = Requests.get_streaming(endpoint(db.url, "_changes"); cookies=db.client.cookies, query=query)
  while !eof(stream)
    line = readline(stream)
    m = match(r"(^{\"seq\":.+?),?\s*$", line)
    if m != nothing
      object = m.captures[1]
      js = JSON.parse(object)
      produce(js)
    end
  end
end