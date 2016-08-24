"""
    paged_mango_query{T<:AbstractString}(db::Database, selector::Selector;
      fields::Vector{T}          = Vector{AbstractString}(),
      sort::Vector{Dict{T, Any}} = Vector{Dict{AbstractString, Any}}(),
      pagesize                   = 100)

Perform multiple HTTP requests against a JSON-type index producing the 
intermediate results. This is a wrapper around `query()` using the 
`skip` and `limit` parameters.

### Examples

    for page in @task paged_mango_query(db, q"data = ..."; pagesize=10)
      for doc in page.docs
        # ... 
      end
    end
"""
function paged_mango_query{T<:AbstractString}(db::Database, selector::Selector;
  fields::Vector{T}          = Vector{AbstractString}(),
  sort::Vector{Dict{T, Any}} = Vector{Dict{AbstractString, Any}}(),
  pagesize                   = 100)

  skip = 0
  while true
    result = mango_query(db, selector; fields=fields, sort=sort, skip=skip, limit=pagesize)
    skip += pagesize
    if length(result.docs) == 0
      break
    end
    produce(result)
  end

end