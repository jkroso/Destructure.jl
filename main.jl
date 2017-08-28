@require "github.com/MikeInnes/MacroTools.jl" => MacroTools flatten @capture @match
@require "github.com/jkroso/Prospects.jl" get

gen_expr(p::Expr, data, dec) = begin
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
    gen_associative(p, temp, dec)
  else
    gen_iteratable(p, temp, dec)
  end
  :($temp = $data; $expr)
end

gen_expr(p::Symbol, data, dec) = p == :_ ? nothing : Expr(dec, :($(esc(p)) = $data))

gen_associative(p, data, dec) = begin
  exprs = map(p.args) do arg
    @match arg begin
      (key_ => pat_ = default_) => gen_expr(pat, :(get($data, $(esc(key)), $(esc(default)))), dec)
      (key_ => pat_) => gen_expr(pat, :(get($data, $(esc(key)))), dec)
      slurp_... => gen_expr(slurp, :(without([$(findnames(p.args)...)], $data)), dec)
      _ => error("unknown format $arg")
    end
  end
  quote $(exprs...) end
end

gen_iteratable(p, data, dec) = begin
  state = gensym(:state)
  expr = quote $state = start($data) end
  for i in 1:length(p.args)
    arg = p.args[i]
    if Meta.isexpr(arg, :...)
      if i == length(p.args)
        push!(expr.args, gen_expr(arg.args[1], :(Iterators.rest($data, $state)), dec))
      else
        remain = length(p.args) - i
        code = quote
          temp = collect(eltype($data), Iterators.rest($data, $state))
          $(gen_expr(arg.args[1], :(temp[1:end-$remain]), dec))
          tail = temp[end-$remain+1:end]
        end
        for j in 1:remain
          push!(code.args, gen_expr(p.args[i+j], :(tail[$j]), dec))
        end
        push!(expr.args, code)
      end
      break
    else
      push!(expr.args, quote
        (item, $state) = next($data, $state)
        $(gen_expr(arg, :item, dec))
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
