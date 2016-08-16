function put_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString, mimetype::AbstractString, file::AbstractString)
  open(file) do f
    Requests.json(put(endpoint(db.url, "$id/$name"); 
      data    = base64encode(readbytes(f)), 
      cookies = db.client.cookies, 
      headers = Dict("Content-Type" => mimetype), 
      query   = Dict("rev" => rev)))
  end
end

function get_attachment(db::Database, id::AbstractString, name::AbstractString; rev::AbstractString = "")
  response = get(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = rev != "" ? Dict("rev" => rev) : Dict())
  base64decode(Requests.bytes(response))
end

function delete_attachment(db::Database, id::AbstractString, rev::AbstractString, name::AbstractString)
  Requests.json(delete(endpoint(db.url, "$id/$name"); cookies = db.client.cookies, query = Dict("rev" => rev)))
end