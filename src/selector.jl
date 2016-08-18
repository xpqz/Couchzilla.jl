"""
    Selector
  
Immutable represention of a Mango Selector used to query a Mango index.

Usually created using the custom string literal `q"..."` (see the `@q_str` macro),
but can be created directly from either the raw json string containing a Selector
expression or a Julia `Dict(...)` representing the same.

## Examples

    ```julia
    sel = q"name = bob"
    sel = Selector("{\"name\":{\"\$eq\":\"bob\"}}")
    sel = Selector(Dict("name" => Dict("\$eq" => "bob")))
    sel = and([q"name = bob", q"age > 18"])
    ```

## API details

* https://docs.cloudant.com/cloudant_query.html#selector-syntax
"""
immutable Selector
  dict::Dict{AbstractString, Any}
end

"""
    Selector()

The empty Selector.
"""
function Selector()
  Selector(Dict{AbstractString, Any}())
end

"""
    Selector(raw_json::AbstractString)

Create a Selector from the raw json.

## API endpoint details

* https://docs.cloudant.com/cloudant_query.html#selector-syntax
"""
function Selector(raw_json::AbstractString) 
  Selector(JSON.parse(raw_json))
end

"""
    isempty(sel::Selector)
  
True if sel is the empty Selector.
"""
function isempty(sel::Selector)
  length(sel.dict) == 0
end

"""
    q"....."
  
Custom string literal for a limited Selector definition DSL.

It takes the form:

    field op data

where `field` is a field name, op is one of 

    =, !=, <, <=, >, >=, in, !in, all

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

For more information on the actual Selector syntax, see link below.

## API endpoint details

* https://docs.cloudant.com/cloudant_query.html#selector-syntax
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
# sel = or( [q"name = bob", q"age > 18"])
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