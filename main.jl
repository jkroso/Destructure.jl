import MacroTools: flatten, @capture, @match

@eval macro $:const(expr)
  @capture(expr, pattern_ = data_) || error("not an assignment expression")
  flatten(gen_expr(pattern, esc(data)))
end

gen_expr(p::Expr, data, isconst=true) = begin
  # convert {a,b} => [:a=>a,:b=>b]
  if Meta.isexpr(p, :cell1d)
    pairs = map(p.args) do e
      @match e begin
        (s_Symbol)          => :($(QuoteNode(s)) => $s)
        (s_Symbol = value_) => :($(QuoteNode(s)) => $e)
        _ => e
      end
    end
    p = :([$(pairs...)])
  end
  @assert Meta.isexpr(p, :vect)
  temp = gensym(:data)
  expr = if any(ispair, p.args)
    gen_associative(p, temp, isconst)
  else
    gen_iteratable(p, temp, isconst)
  end
  :(const $temp = $data; $expr)
end

gen_expr(p::Symbol, data, isconst=true) = p == :_ ? nothing : Expr(isconst ? :const : :block, :($(esc(p)) = $data))

gen_associative(p, data, isconst) = begin
  exprs = map(p.args) do arg
    if Meta.isexpr(arg, :...)
      gen_expr(arg.args[1], :(without([$(findnames(p.args)...)], $data)), isconst)
    elseif Meta.isexpr(arg.args[3], :(=), 2)
      gen_expr(arg.args[3].args[1], :(getkey($data, $(arg.args[2]), $(arg.args[3].args[2]))), isconst)
    else
      gen_expr(arg.args[3], :(getkey($data, $(arg.args[2]))), isconst)
    end
  end
  quote $(exprs...) end
end

gen_iteratable(p, data, isconst) = begin
  state = gensym(:state)
  expr = quote $state = start($data) end
  for i in 1:length(p.args)
    arg = p.args[i]
    if Meta.isexpr(arg, :...)
      if i == length(p.args)
        push!(expr.args, gen_expr(arg.args[1], :(rest($data, $state)), isconst))
      else
        remain = length(p.args) - i
        code = quote
          const temp = rest($data, $state)
          $(gen_expr(arg.args[1], :(temp[1:end-$remain]), isconst))
          tail = temp[end-$remain+1:end]
        end
        for j in 1:remain
          push!(code.args, gen_expr(p.args[i+j], :(tail[$j]), isconst))
        end
        push!(expr.args, code)
      end
      break
    else
      push!(expr.args, quote
        item, $state = next($data, $state)
        $(gen_expr(arg, :item, isconst))
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

macro destruct(expr)
  if @capture(expr, function f_(args__) body_ end | f_(args__)=body_)
    extra = quote end
    for (i, param) in enumerate(args)
      pattern, T = norm_param(param)
      pattern isa Symbol && continue
      temp = gensym()
      push!(extra.args, gen_expr(pattern, esc(temp), false))
      args[i] = :($temp::$T)
    end
    :($(esc(f))($(map(esc, args)...)) = ($extra; $(esc(body)))) |> flatten
  elseif @capture(expr, pattern_ = data_)
    flatten(gen_expr(pattern, esc(data), false))
  else
    error("unrecognised input: $expr")
  end
end

norm_param(e) = Meta.isexpr(e, :(::), 2) ? (e.args[1], e.args[2]) : (e, Any)
