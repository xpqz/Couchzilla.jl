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

macro q_str(data)
  quote
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

    m = match(r"^(.+?)\s*(==|=|!=|<|<=|>|>=|in|!in|all)\s*\[?(.+)\]?$", strip($(data)))
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
  
    mydict = Dict(field => Dict(operators[operator] => value))
    Selector(mydict)
  end
end

# Operations on arrays of selectors
for boolop in [:and, :or, :nor]
  boolop_str = "\$"*string(boolop)
  @eval begin
    function ($boolop)(sel::Vector{Selector})
      Selector(Dict($boolop_str => map(sel) do s
        s.dict
      end))
    end
  end
end

# Selector modifiers
for op in [:not]
  op_str = "\$"*string(op)
  @eval begin
    function ($op)(sel::Selector)
      Selector(Dict($op_str => sel.dict))
    end
  end
end