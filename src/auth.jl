"""
    data = get_permissions(db::Database)

Fetch all current permissions. Note: this is Cloudant-specific.

[API reference](https://docs.cloudant.com/authorization.html#viewing-permissions)
"""
function get_permissions(db::Database)
  relax(get, endpoint(db.client.url, "_api/v2/db/$(db.name)/_security"); cookies=db.client.cookies)
end

"""
    result = set_permissions(db::Database; data=Dict{Any, Any}())

Modify permissions. Note: this is Cloudant-specific.

[API reference](https://docs.cloudant.com/authorization.html#modifying-permissions)
"""
function set_permissions(db::Database, current::Dict=Dict{AbstractString, Any}(); key="", roles=[])
  if key != "" && length(roles) == 0
    error("No roles provided for key")
  end
  if !haskey(current, "cloudant") && key == ""
    error("Expected a non-empty permissions dict or a non-empty key")
  end

  if !haskey(current, "cloudant")
    current["cloudant"] = Dict(key => roles)
  else
    current["cloudant"][key] = roles
  end

  relax(put, endpoint(db.client.url, "_api/v2/db/$(db.name)/_security"); json=current, cookies=db.client.cookies)
end

"""
    data = make_api_key(client::Client)

Generate a new API key. Note: this is Cloudant-specific.

Note also that API keys take a long time to propagate around a cluster. It's unsafe to rely
on a newly created key to be immediately available. The reason for this is that Cloudant keeps
its auth-related documents centrally, and replicate out to all clusters. 

[API reference](https://docs.cloudant.com/authorization.html#creating-api-keys)
"""
function make_api_key(client::Client)
  relax(post, endpoint(client.url, "_api/v2/api_keys"); cookies=client.cookies)
end

"""
    result = delete_api_key(db::Database, key::AbstractString)

Remove an existing API key. Note: this is Cloudant-specific. This is implemented via `set_permissions()`.

[API reference](https://docs.cloudant.com/authorization.html#deleting-api-keys)
"""
function delete_api_key(db::Database, key::AbstractString)
  current = get_permissions(db)
  if haskey(current, "cloudant") && haskey(current["cloudant"], key)
    delete!(current["cloudant"], key)
    set_permissions(db, current)
    return true
  end
  false
end