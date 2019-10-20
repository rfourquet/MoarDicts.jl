using FlatCollections, Random, Test

const TYPES = (Nothing, Missing, Int32, Int64, BigInt,
               Float32, Float64, BigFloat, String, Symbol)

_rand(::Type{T}) where {T} = rand(T)
_rand(::Type{BigInt}) = rand(big.(typemin(Int128):typemax(Int128)))
_rand(T::Type{<:Union{String,Symbol}}) = T(randstring())
_rand(T::Type{<:Union{Missing,Nothing}}) = T()

include("FlatDict.jl")
