using FlatCollections, Random, Test

const TYPES = (Nothing, Missing, Int32, Int64, BigInt,
               Float32, Float64, BigFloat, String, Symbol)

_rand(::Type{T}) where {T} = rand(T)
_rand(::Type{BigInt}) = rand(big.(typemin(Int128):typemax(Int128)))
_rand(T::Type{<:Union{String,Symbol}}) = T(randstring())
_rand(T::Type{<:Union{Missing,Nothing}}) = T()

# return a pair of types, the first of which is not Nothing
# (Nothing is not a valid key type, as isless is not implemented)
function _randtypes()
    A, B = rand(TYPES, 2)
    A === Nothing && return _randtypes()
    A, B
end

# same as in julia/test/show.jl
replstr(x, kv::Pair...) = sprint((io,x) -> show(IOContext(io, :limit => true, :displaysize => (24, 80), kv...), MIME("text/plain"), x), x)
showstr(x, kv::Pair...) = sprint((io,x) -> show(IOContext(io, :limit => true, :displaysize => (24, 80), kv...), x), x)
