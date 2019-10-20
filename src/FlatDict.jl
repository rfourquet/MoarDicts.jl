## construction

NewPair{K,V} = Union{Pair{K,Some{V}},
                     Pair{K,Nothing}}

struct FlatDict{K,V} <: AbstractDict{K,V}
    keys::Vector{K}
    vals::Vector{V}
    news::Vector{NewPair{K,V}}

    FlatDict{K,V}() where {K,V} =
        new(Vector{K}(), Vector{V}(), Vector{NewPair{K,V}}())
end


## update

_setindex!(fd::FlatDict, val, key) = push!(fd.news, key => Some(val))

function setindex!(fd::FlatDict, val, key)
    _setindex!(fd, val, key)
end


## query

function get(fd::FlatDict, key, default)
    idx = findlast(kv -> isequal(key, first(kv)), fd.news)
    if idx === nothing
        default
    else
        val = last(fd.news[idx])
        val === nothing ? default : something(val)
    end
end
