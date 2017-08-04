# Descructure.jl

Destructuring assignment macros

## Installation

With [Kip.jl](//github.com/jkroso/Kip.jl)

```julia
@require "github.com/jkroso/Destructure.jl" @const @destruct
```

Otherwise

```julia
Pkg.clone("https://github.com/jkroso/Destructure.jl")
using Destructure
```

## Usage

- `_` will just drop the value
- `...` will greedily collect values

```julia
@destruct [_, tail...] = 1:3
@assert tail == [2,3]
@destruct [_, tail..., last] = 1:3
@assert tail == [2] && last == 3
```

It works on `Associative` like objects too:

```julia
@destruct [:a=>a, rest...] = Dict(:a=>1,:b=>2)
@assert a == 1 && rest == Dict(:b=>2)
# It treats objects like Associative's
@destruct [:num=>num, :den=>den, rest...] = 1//2
@assert num == 1 && den == 2 && rest == Dict()
# Default values work with Associative's
@destruct [:a=>a=0] = Dict()
@assert a == 0
```

And it's recursive so you can go several levels down into objects to get what you want. And `@const` is just like `@destruct` except it declares all variables with `const`.

```julia
@const [_, [:a=>[b]]] [1, Dict(:a=>[2])]
@assert b == 2 && isconst(:b)
```

And you can use it in your function's parameters:

```julia
@destruct name([:name=>n]::Dict) = n
@assert name(Dict(:name=>"Jake")) == "Jake"
```
