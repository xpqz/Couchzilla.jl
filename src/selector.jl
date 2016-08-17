immutable Selector
  dict::Dict{AbstractString, Any}
end

function Selector()
  Selector(Dict{AbstractString, Any}())
end

"""
Create a Selector from the raw json.

```julia
Selector(raw_json::AbstractString)
```
"""
function Selector(raw_json::AbstractString) 
  Selector(JSON.parse(raw_json))
end

"""
Check if a Selector is empty

```julia
isempty(sel::Selector)
```
"""
function isempty(sel::Selector)
  length(sel.dict) == 0
end

"""
Custom string literal for a limited Selector definition DSL.

It takes the form:

`field op data`

where `field` is a field name, op is one of 

`=, !=, <, <=, >, >=, in, !in, all`

This allows you to write things like:

q"name = bob"
q"value < 5"
q"occupation in [fishmonger, pilot, welder]"

Note that the Selector DSL only covers a fraction of the full Selector
syntax. It can be used with the boolean functions `and()`, `or()` etc
to build up more complex Selectors, e.g.

```julia
sel = and([q"name = bob", q"age > 18"])
```

For more information on the actual Selector syntax, see

https://docs.cloudant.com/cloudant_query.html#selector-syntax
"""
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

# Boolean logic composition of Selectors:
#
# sel = and([q"name = bob", q"age > 18"])
# sel = or([q"name = bob", q"age > 18"])
# sel = nor([q"name = bob", q"age > 18"])
# 
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

# Selector modifiers:
#
# sel = not(and([q"name = bob", q"age > 18"]))
# 
for op in [:not]
  op_str = "\$"*string(op)
  @eval begin
    function ($op)(sel::Selector)
      Selector(Dict($op_str => sel.dict))
    end
  end
end