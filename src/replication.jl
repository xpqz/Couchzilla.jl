# The CouchDB replication API

# This should be run as a Task
function changes(db::Database, options)
  get_url = string(endpoint(db.url, "_changes"))
  stream = Requests.get_streaming(get_url, cookies=db.client.cookies, query=options)
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