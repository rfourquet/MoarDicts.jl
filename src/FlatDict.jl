# construction

NewPair{K,V} = Union{Pair{K,Some{V}},
                     Pair{K,Nothing}}

struct FlatDict{K,V} <: AbstractDict{K,V}
    keys::Vector{K}
    vals::Vector{V}
    news::Vector{NewPair{K,V}}

    FlatDict{K,V}() where {K,V} =
        new(Vector{K}(), Vector{V}(), Vector{NewPair{K,V}}())
end
