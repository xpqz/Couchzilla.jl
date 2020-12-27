settings = Dict(
  "retry" => Dict("enabled" => false, "max_retries" => 5, "delay_ms" => 10)
)

"""
    retry_settings!(;enabled=false, max_retries=5, delay_ms=10)

Set parameters for retrying requests failed with a 429: Too Many Requests.
This is Cloudant-specific, but safe to leave enabled if using CouchDB, as
the error will never be encountered.

Failed requests are retried after a growing interval according to

    sleep((tries * delay_ms + rand(1:10))/1000.0)

until `tries` exceed `max_retries` or the request succeeds.

Note: it is not sufficient to rely on this behaviour on a rate-limited Cloudant cluster,
as persistently hitting the limits can only be fixed by moving to higher reserved 
throughput capacity. For this reason this is disabled by default.
"""
function retry_settings!(;enabled=false, max_retries=5, delay_ms=10)
  settings["retry"] = Dict(
    "enabled"     => enabled, 
    "max_retries" => max_retries, 
    "delay_ms"    => delay_ms
  )
  nothing
end

"""
    retry_settings()

Return the current retry settings.
"""
function retry_settings()
  settings["retry"]
end

"""
    struct HTTPException <: Exception
      status
      response
      request
      message
    end

HTTP error exception, thrown by `relax()`.
"""
struct HTTPException <: Exception
  status
  response
  request
  message
end

function Base.show(io::IO, err::HTTPException)
  print(io, "HTTPException - status: $(err.status) request: $(err.request) response: $(err.response) message: $(err.message)")
end

"""
    relax(fun, url_string; cookies=nothing, query=Dict(), headers=Dict())

Makes an HTTP request with the relevant cookies and query strings
and deserialises the response, assumed to be json.

Cloudant implements request throttling based on reerved throughput capacity. Hitting a 
capacity limit will return a 429 error (Too many requests). This is Cloudant-specific.

This function can retry on 429 if this behaviour is enabled. See `retry_settings()`.
"""
function relax(fun, url_string; cookies=nothing, query=Dict(), headers=Dict(), json=Dict())
  # if cookies == nothing
  #   error("Not authenticated")
  # end
  settings = retry_settings()
  tries = 0
  headers["Content-Type"] = "application/json"
  while true
    response = cookies == "" ? fun(url_string, headers=headers, body=JSON.json(json); query=query) : fun(url_string, headers=headers, body=JSON.json(json); cookies=true, query=query)

    if response.status == 429 && settings["enabled"]
      tries += 1
      if tries > settings["max_retries"]
        throw(HTTPException(response.status, "Too many requests", "request", "max retries reached"))
      end
      sleep((tries * settings["delay_ms"] + rand(1:10))/1000.0)
      continue
    end
    if response.status in 400:599
      throw(HTTPException(response.status, JSON.json(response), string(response.request), ""))
      throw(HTTPException(response.status, JSON.json(response), ""))
    else
      return JSON.parse(String(response.body))
    end
  end
end

"""
    endpoint(uri::URI, path::AbstractString)

Appends a path string to the URI, returning as a string.
"""
function endpoint(uri::URI, path::AbstractString)
  string(URI(uri.scheme, uri.host, uri.port, replace("$(uri.path)/$path", r"//" => s"/")))
end
