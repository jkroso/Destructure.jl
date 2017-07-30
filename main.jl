import MacroTools.flatten

macro assign(pattern, data) flatten(gen_expr(pattern, data)) end

gen_expr(p::Expr, data) = begin
  @assert Meta.isexpr(p, :vect)
  temp = gensym(:data)
  quote
    $temp = $data
    $(if any(ispair, p.args) gen_associative(p, temp)
      else gen_iteratable(p, temp)
      end)
  end
end

gen_expr(p::Symbol, data) = p == :_ ? nothing : :($(esc(p)) = $data)

gen_associative(p, data) = begin
  exprs = map(p.args) do arg
    if Meta.isexpr(arg, :...)
      gen_expr(arg.args[1], :(without(Any[$(findnames(p.args)...)], $data)))
    else
      gen_expr(arg.args[3], :(getkey($data, $(arg.args[2]))))
    end
  end
  quote $(exprs...) end
end

gen_iteratable(p, data) = begin
  state = gensym(:state)
  expr = quote $state = start($data) end
  for i in 1:length(p.args)
    arg = p.args[i]
    if Meta.isexpr(arg, :...)
      if i == length(p.args)
        push!(expr.args, gen_expr(arg.args[1], :(rest($data, $state))))
      else
        remain = length(p.args) - i
        code = quote
          temp = rest($data, $state)
          $(gen_expr(arg.args[1], :(temp[1:end-$remain])))
          tail = temp[end-$remain+1:end]
        end
        for j in 1:remain
          push!(code.args, gen_expr(p.args[i+j], :(tail[$j])))
        end
        push!(expr.args, code)
      end
      break
    else
      push!(expr.args, quote
        item, $state = next($data, $state)
        $(gen_expr(arg, :item))
      end)
    end
  end
  expr
end

ispair(p) = Meta.isexpr(p, :call, 3) && p.args[1] == :(=>)
findnames(args) = map(p->p.args[2], filter(ispair, args))
without(fields, a::Associative) = filter((k,v)->!(k in fields), a)
without(fields, a) = begin
  out = Dict()
  for f in fieldnames(a)
    f in fields && continue
    out[f] = a.(f)
  end
  out
end

rest(itr, state) = begin
  out = Vector{eltype(itr)}()
  while !done(itr, state)
    value, state = next(itr, state)
    push!(out, value)
  end
  out
end

getkey(a, key) = begin
  a = getkey(a, key, Base.secret_table_token)
  a ≡ Base.secret_table_token && throw(KeyError(key))
  return a
end

getkey(a::Associative, key, default) = get(a, key, default)
getkey(object, key, default) = isdefined(object, key::Symbol) ? getfield(object, key) : default
getkey(t::Tuple, i, default) = isdefined(t, i) ? getindex(t, i) : default
