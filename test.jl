using Test
include("main.jl")

@destruct {a} = Dict(:a=>1)
@test a == 1
@destruct {a, tail...} = Dict(:a=>0,:b=>1,:c=>2)
@test a == 0 && tail == Dict(:b=>1,:c=>2)
@destruct [_,a,b] = [1,2,3]
@test a == 2 && b == 3
@destruct [_,tail...] = [1,2,3]
@test collect(tail) == [2,3]
@destruct [_,tail...,a] = [1,2,3,4,5]
@test tail == [2,3,4] && a == 5

@destruct {:d=>{child},tail...} = Dict(:d=>Dict(:child=>1))
@test child == 1 && tail == Dict() && !isdefined(@__MODULE__(), :d)
@destruct {a=>{child},tail...} = Dict(:a=>Dict(:child=>2))
@test child == 2 && tail == Dict() && a == Dict(:child=>2)

@destruct [[a],[b],tail...] = [[1],[2]]
@test a == 1 && b == 2 && collect(tail) == []

@destruct [{a},[b],tail...] = [Dict(:a=>0),[1]]
@test a == 0 && b == 1 && collect(tail) == []

@destruct {num, den, tail...} = 1//2
@test num == 1 && den == 2 && tail == Dict()

@destruct {:a=>(a=1)} = Dict()
@test a == 1

@destruct {a=2} = Dict()
@test a == 2

@destruct destruct({a}::Dict,b) = (a,b)
@test destruct(Dict(:a=>1),2) == (1,2)

@const {d, dtail..., :f=>[f]} = Dict(:d=>1,:e=>2,:f=>[3])
@test d == 1 && dtail == Dict(:e=>2) && f == 3 && isconst(@__MODULE__(), :d) && isconst(@__MODULE__(), :dtail) && isconst(@__MODULE__(), :f)

@destruct {"text"=>text} = Dict("text"=>"sometext")
@test text == "sometext"

@destruct {e=1, etail...} = Dict(:e=>2,:b=>3)
@test e == 2 && etail == Dict(:b=>3)
