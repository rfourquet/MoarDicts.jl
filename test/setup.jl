using FlatCollections, Random, Test

_rand(::Type{T}) where {T} = rand(T)
_rand(::Type{BigInt}) = rand(big.(typemin(Int128):typemax(Int128)))
_rand(T::Type{<:Union{String,Symbol}}) = T(randstring())
_rand(T::Type{<:Union{Missing,Nothing}}) = T()

# return a pair of types, the first of which is not Nothing
# (Nothing is not a valid key type, as isless is not implemented)
function _randtypes(types)
    A, B = rand(types, 2)
    A === Nothing && return _randtypes(types)
    A, B
end

# same as in julia/test/show.jl
replstr(x, kv::Pair...) = sprint((io,x) -> show(IOContext(io, :limit => true, :displaysize => (24, 80), kv...), MIME("text/plain"), x), x)
showstr(x, kv::Pair...) = sprint((io,x) -> show(IOContext(io, :limit => true, :displaysize => (24, 80), kv...), x), x)

mutable struct TestArgs
    ntypescombos::Int
    special::Bool
    types::Vector{DataType}
end

TestArgs() = TestArgs(10,
                      true,
                      DataType[Nothing, Missing, String, Symbol,
                               Bool, Int8, UInt8, Int32, Int64, BigInt,
                               Float32, Float64, BigFloat])

const TEST_ARGS = TestArgs()

function _isvalidkey(::Type{T}) where T
    x = _rand(T)
    try
        isless(x, x)
        return true
    catch
        return false
    end
end

_nvalidkeys(types) = count(_isvalidkey, types)

function parse_test_args!(args=ARGS)
    for arg in args
        if startswith(arg, "ncombos=")
            TEST_ARGS.ntypescombos = parse(Int, arg[9:end])
        elseif startswith(arg, "types=")
            types = getfield.(Ref(Main), Symbol.(split(arg[7:end], ',')))
            copy!(TEST_ARGS.types, types)
        elseif startswith(arg, "special=")
            TEST_ARGS.special = parse(Bool, arg[9:end])
        else
            @info "ignored argument: $arg"
        end
    end
    TEST_ARGS
end

parse_test_args!()

function gettypes()
    ntypescombos, types = TEST_ARGS.ntypescombos, TEST_ARGS.types
    unique!(types)
    # we divide by 2 as random selection would take too long otherwise
    combos =
        if ntypescombos >= _nvalidkeys(types) * length(types) ÷ 2
            [(A, B) for A in types if _isvalidkey(A)
                    for B in types]
        else
            AB = Set{Tuple{DataType,DataType}}()
            nonnothing = setdiff(types, [Nothing])
            floats = intersect(types, Base.uniontypes(Base.IEEEFloat))
            if TEST_ARGS.special && !isempty(nonnothing)
                if Missing in types
                    push!(AB, (Missing, rand(types)))
                    push!(AB, (rand(nonnothing), Missing))
                end
                if Nothing in types
                    push!(AB, (rand(nonnothing), Nothing))
                end
                if Bool in types
                    push!(AB, (Bool, rand(types)))
                end
                if !isempty(floats)
                    push!(AB, (rand(floats), rand(types)))
                    push!(AB, (rand(nonnothing), rand(floats)))
                end
                smalls = intersect!([Int8, UInt8], types)
                if length(AB) + 3 < ntypescombos && !isempty(smalls)
                    push!(AB, (rand(smalls), rand(types)))
                end
            end
            while length(AB) > ntypescombos
                pop!(AB, rand(AB))
            end
            while length(AB) < ntypescombos
                push!(AB, _randtypes(types))
            end
            collect(AB)
        end
    sort!(combos, by=x->string.(x))
end
