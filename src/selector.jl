immutable Selector
  dict::Dict{AbstractString, Any}
end

function Selector()
  Selector(Dict{AbstractString, Any}())
end

function Selector(raw_json::AbstractString) 
  Selector(JSON.parse(raw_json))
end

function Selector(op::AbstractString, selectors::Array{Selector, 1}) 
  Selector(Dict(op => selectors))
end

function isempty(sel::Selector)
  length(sel.dict) == 0
end

macro q_str(data::AbstractString)
  operators = Dict{UTF8String, UTF8String}(
    "=="  => "\$eq",
    "="   => "\$eq",
    "!="  => "\$ne",
    "<"   => "\$lt",
    "<="  => "\$lte",
    ">"   => "\$gt",
    ">="  => "\$gte",
    "in"  => "\$in",
    "!in" => "\$nin",
    "all" => "\$all"
  )

  m = match(r"^(.+?)\s*(==|=|!=|<|<=|>|>=|in|!in|all)\s*\[?(.+)\]?$", strip(data))
  if m == nothing
    error("Badly formatted selector string")
  end

  field    = m.captures[1]
  operator = m.captures[2]
  value    = m.captures[3]

  if !haskey(operators, operator)
    error("Unknown operator '$operator'")
  end

  if operator in ["in", "!in", "all"]
    value = map(strip, split(value, ","))
  end

  Dict(field => Dict(operators[operator] => value))
end