using Base.Test
include("main.jl")

@assign [:a=>a] Dict(:a=>1)
@test a == 1
@assign [:a=>a,tail...] Dict(:a=>0,:b=>1,:c=>2)
@test a == 0 && tail == Dict(:b=>1,:c=>2)
@assign [_,a,b] [1,2,3]
@test a == 2
@assign [_,tail...] [1,2,3]
@test tail == [2,3]
@assign [_,tail...,a] [1,2,3,4,5]
@test tail == [2,3,4] && a == 5

@assign [:a=>[:b=>child],tail...] Dict(:a=>Dict(:b=>1))
@test child == 1 && tail == Dict()

@assign [[a],[b],tail...] [[1],[2]]
@test a == 1 && b == 2 && tail == []

@assign [[:a=>a],[b],tail...] [Dict(:a=>0),[1]]
@test a == 0 && b == 1 && tail == []

@assign [:num=>num,:den=>den, tail...] 1//2
@test num == 1 && den == 2 && tail == Dict()

@assign [:a=>a=1] Dict()
@test a == 1
