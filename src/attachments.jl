# Implementation of the CouchDB Attachment API

"""
    put_attachment(db::Database, 
      id::AbstractString, 
      rev::AbstractString, 
      name::AbstractString, 
      mimetype::AbstractString, 
      file::AbstractString)

Write an attachment to an existing document. Attachment read from a file.

## Examples

    doc = createdoc(db, Dict("item" => "screenshot"))
    result = put_attachment(db, doc["id"], doc["rev"], "test.png", "image/png", "data/test.png")

## API endpoint details

* https://docs.cloudant.com/attachments.html
"""
function put_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString, mimetype::AbstractString, file::AbstractString)
  open(file) do f
    Requests.json(put(endpoint(db.url, "$id/$name"); 
      data    = base64encode(readbytes(f)), 
      cookies = db.client.cookies, 
      headers = Dict("Content-Type" => mimetype), 
      query   = Dict("rev" => rev)))
  end
end

"""
    get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")

Read an attachment.

## Examples

    att = get_attachment(db, id, "test.png"; rev=rev)
    open("data/fetched.png", "w") do f
      write(f, att)
    end

## API endpoint details

* https://docs.cloudant.com/attachments.html
"""
function get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
  response = get(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = rev != "" ? Dict("rev" => rev) : Dict())
  base64decode(Requests.bytes(response))
end

"""
    delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)

Delete an attachment.

## Examples

    result = delete_attachment(db, id, rev, "test.png")

## API endpoint details

* https://docs.cloudant.com/attachments.html
"""
function delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
  Requests.json(delete(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = Dict("rev" => rev)))
end