# Implementation of the CouchDB Attachment API

"""
    put_attachment(db::Database, 
      id::AbstractString, 
      rev::AbstractString, 
      name::AbstractString, 
      mimetype::AbstractString, 
      file::AbstractString)

Write an attachment to an existing document. Attachment read from a file.

### Examples

    doc = createdoc(db, Dict("item" => "screenshot"))
    result = put_attachment(db, doc["id"], doc["rev"], "test.png", "image/png", "data/test.png")

[API reference](https://docs.cloudant.com/attachments.html)
"""
function put_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString, mimetype::AbstractString, file::AbstractString)
  open(file) do f
    headers = Dict("Content-Type" => mimetype)
    data    = base64encode(read(f))
    response = HTTP.put(endpoint(db.url, "$id/$name"), headers, data;
      cookies = db.client.cookies,
      query   = Dict("rev" => rev))
    JSON.parse(String(response.body))
  end
end

"""
    result = get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")

Read an attachment.

### Examples

    att = get_attachment(db, id, "test.png"; rev=rev)
    open("data/fetched.png", "w") do f
      write(f, att)
    end

[API reference](https://docs.cloudant.com/attachments.html)
"""
function get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
  response = HTTP.get(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = rev != "" ? Dict("rev" => rev) : Dict())
  base64decode(response.body)
end

"""
    result = delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)

Delete an attachment.

### Examples

    result = delete_attachment(db, id, rev, "test.png")

[API reference](https://docs.cloudant.com/attachments.html)
"""
function delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
  relax(HTTP.delete, endpoint(db.url, "$id/$name"); cookies=db.client.cookies, query=Dict("rev" => rev))
end
