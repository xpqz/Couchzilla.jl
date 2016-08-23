"""
    immutable HTTPException <: Exception 
      status
      response
      request
    end

HTTP error exception, thrown by `relax()`.
"""
immutable HTTPException <: Exception 
  status
  response
  request
end

function Base.show(io::IO, err::HTTPException)
  print(io, "HTTPException - status: $(err.status) request: $(err.request) response: $(err.response)")
end

"""
    relax(fun, url_string; cookies=nothing, query=Dict(), headers=Dict())

Makes an HTTP request with the relevant cookies and query strings
and deserialises the response, assumed to be json.
"""
function relax(fun, url_string; cookies=nothing, query=Dict(), headers=Dict(), json=Dict())
  if cookies == nothing
    error("Not authenticated")
  end
  response = fun(url_string; cookies=cookies, query=query, headers=headers, json=json)
  if response.status in 400:599
    request = requestfor(response)
    throw(HTTPException(response.status, Requests.json(response), string(request)))
  else
    Requests.json(response)
  end
end

"""
    endpoint(uri::URI, path::AbstractString)

Appends a path string to the URI, returning as a string.
"""
function endpoint(uri::URI, path::AbstractString)
  string(URI(uri.scheme, uri.host, uri.port, replace("$(uri.path)/$path", "//", "/")))
end