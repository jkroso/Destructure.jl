@require "github.com/MikeInnes/MacroTools.jl" => MacroTools flatten @capture @match
@require "github.com/jkroso/Prospects.jl" get

gen_expr(p::Expr, data, dec, name=toname(p)) = begin
  expr = if Meta.isexpr(p, :braces)
    gen_associative(p, name, dec)
  elseif Meta.isexpr(p, :vect)
    gen_iteratable(p, name, dec)
  else
    error("unknown destructuring pattern: $p")
  end
  :($name = $data; $expr)
end

gen_expr(p::Symbol, data, dec, name=toname(p)) = p == :_ ? nothing : Expr(dec, :($name = $data))

gen_associative(p, data, dec) = begin
  exprs = map(p.args) do arg
    @match arg begin
      (key_ => (pat_ = default_)) => gen_expr(pat, :(get($data, $(tokey(key)), $(esc(default)))), dec, toname(pat))
      (key_Symbol => pat_) => gen_expr(pat, :(get($data, $(tokey(key)))), dec, toname(key))
      (key_ => pat_) => gen_expr(pat, :(get($data, $(tokey(key)))), dec)
      slurp_... => gen_expr(slurp, :(without([$(findkeys(p.args)...)], $data)), dec)
      (key_ = default_) => Expr(dec, :($(esc(key)) = get($data, $(QuoteNode(key)), $(esc(default)))))
      key_ => Expr(dec, :($(esc(key)) = get($data, $(QuoteNode(key)))))
    end
  end
  quote $(exprs...) end
end

toname(s::Symbol) = esc(s)
toname(s) = Symbol(string(s))

gen_iteratable(p, data, dec) = begin
  state = gensym(:state)
  out = quote $state = iterate($data) end
  for i in 1:length(p.args)
    arg = p.args[i]
    if Meta.isexpr(arg, :...)
      if i == length(p.args)
        push!(out.args, gen_expr(arg.args[1], :($state == nothing ? [] : [$state[1], Iterators.rest($data, $state[2])...]), dec))
      else
        remain = length(p.args) - i
        code = quote
          temp = [$state[1], Iterators.rest($data, $state[2])...]
          $(gen_expr(arg.args[1], :(temp[1:end-$remain]), dec))
          tail = temp[end-$remain+1:end]
        end
        for j in 1:remain
          push!(code.args, gen_expr(p.args[i+j], :(tail[$j]), dec))
        end
        push!(out.args, code)
      end
      break
    else
      push!(out.args, quote
        @assert $state != nothing
        item = $state[1]
        $state = iterate($data, $state[2])
        $(gen_expr(arg, :item, dec))
      end)
    end
  end
  out
end

findkeys(args) = filter(x->x!=nothing, map(tokey, args))
tokey(arg) = @match arg begin
  (_...) => nothing
  (key_Symbol => _) => QuoteNode(key)
  (key_Symbol = _) => QuoteNode(key)
  (key_ => _) => key
  key_Symbol => QuoteNode(key)
  key_ => key
end
without(fields, a::AbstractDict) = filter(((k,_),)->!in(k, fields), a)
without(fields, a) =
  Dict(f => getproperty(a, f) for f in propertynames(a) if !in(f, fields))

norm_param(e) = Meta.isexpr(e, :(::), 2) ? (e.args[1], e.args[2]) : (e, Any)

handle_macro(expr, declaration) = begin
  if @capture(expr, function f_(args__) body_ end | f_(args__)=body_)
    extra = quote end
    for (i, param) in enumerate(args)
      pattern, T = norm_param(param)
      pattern isa Symbol && continue
      temp = gensym()
      push!(extra.args, gen_expr(pattern, esc(temp), :local))
      args[i] = :($temp::$T)
    end
    :($(esc(f))($(map(esc, args)...)) = ($extra; $(esc(body)))) |> flatten
  elseif @capture(expr, pattern_ = data_)
    flatten(gen_expr(pattern, esc(data), declaration))
  else
    error("unrecognised input: $expr")
  end
end

@eval macro $:const(expr) handle_macro(expr, :const) end
@eval macro $:destruct(expr) handle_macro(expr, :block) end
