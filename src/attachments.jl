"""
Write an attachment to an existing document. Attachment read from a file.

```julia
put_attachment(db::Database, 
  id::AbstractString, 
  rev::AbstractString, 
  name::AbstractString, 
  mimetype::AbstractString, 
  file::AbstractString)
```

See https://docs.cloudant.com/attachments.html
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
Read an attachment.

```julia
get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
```

See https://docs.cloudant.com/attachments.html
"""
function get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
  response = get(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = rev != "" ? Dict("rev" => rev) : Dict())
  base64decode(Requests.bytes(response))
end

"""
Delete an attachment.

```julia
delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
```

See https://docs.cloudant.com/attachments.html
"""
function delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
  Requests.json(delete(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = Dict("rev" => rev)))
end