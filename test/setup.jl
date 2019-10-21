using FlatCollections, Random, Test

const TYPES = DataType[Nothing, Missing, Int32, Int64, BigInt,
                       Float32, Float64, BigFloat, String, Symbol]

function _isvalidkey(::Type{T}) where T
    x = _rand(T)
    try
        isless(x, x)
        return true
    catch
        return false
    end
end

_nvalidkeys() = count(_isvalidkey, TYPES)

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

mutable struct TestArgs
    ntypescombos::Int
end

TestArgs() = TestArgs(1)

const TEST_ARGS = TestArgs(1)

function parse_test_args!(args=ARGS)
    for arg in args
        if startswith(arg, "ncombos=")
            TEST_ARGS.ntypescombos = parse(Int, arg[9:end])
        else
            @info "ignored argument: $arg"
        end
    end
    TEST_ARGS
end

parse_test_args!()

function gettypes()
    # we divide by 2 as random selection would take too long otherwise
    combos =
        if TEST_ARGS.ntypescombos >= _nvalidkeys() * length(TYPES) ÷ 2
            [(A, B) for A in TYPES if _isvalidkey(A)
                    for B in TYPES]
        else
            AB = Set{Tuple{DataType,DataType}}()
            while length(AB) < TEST_ARGS.ntypescombos
                push!(AB, _randtypes())
            end
            collect(AB)
        end
    sort!(combos, by=x->string.(x))
end
