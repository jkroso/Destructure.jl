using Base.Test
include("main.jl")

@destruct {a} = Dict(:a=>1)
@test a == 1
@destruct {a, tail...} = Dict(:a=>0,:b=>1,:c=>2)
@test a == 0 && tail == Dict(:b=>1,:c=>2)
@destruct [_,a,b] = [1,2,3]
@test a == 2
@destruct [_,tail...] = [1,2,3]
@test tail == [2,3]
@destruct [_,tail...,a] = [1,2,3,4,5]
@test tail == [2,3,4] && a == 5

@destruct {:a=>{child},tail...} = Dict(:a=>Dict(:child=>1))
@test child == 1 && tail == Dict()

@destruct [[a],[b],tail...] = [[1],[2]]
@test a == 1 && b == 2 && tail == []

@destruct [{a},[b],tail...] = [Dict(:a=>0),[1]]
@test a == 0 && b == 1 && tail == []

@destruct {num, den, tail...} = 1//2
@test num == 1 && den == 2 && tail == Dict()

@destruct [:a=>a=1] = Dict()
@test a == 1

@destruct {a=2} = Dict()
@test a == 2

@destruct destruct({a}::Dict,b) = (a,b)
@test destruct(Dict(:a=>1),2) == (1,2)

@const {d, dtail..., :f=>[f]} = Dict(:d=>1,:e=>2,:f=>[3])
@test d == 1 && dtail == Dict(:e=>2) && f == 3 && isconst(:d) && isconst(:dtail) && isconst(:f)
