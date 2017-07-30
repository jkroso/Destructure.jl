# Descructure.jl

Destructuring assignment macros

## Installation

With [Kip.jl](//github.com/jkroso/Kip.jl)

```julia
@require "github.com/jkroso/Destructure.jl" @assign
```

<!-- Otherwise

```julia
Pkg.clone("https://github.com/jkroso/Descructure.jl")
import Descructure: @assign
``` -->

## Usage

- `_` will just drop the value
- `...` will greedily collect values

```julia
@assign [_, tail...] 1:3
@assert tail == [2,3]
@assign [_, tail..., last] 1:3
@assert tail == [2] && last == 3
```

It works on `Associative` like objects too:

```julia
@assign [:a=>a, rest...] Dict(:a=>1,:b=>2)
@assert a == 1 && rest == Dict(:b=>2)
@assign [:num=>num, :den=>den, rest...] 1//2
@assert num == 1 && den == 2 && rest == Dict()
```
