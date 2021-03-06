module MoarDicts

import Base: ==, _typeddict, convert, copy, copy!, delete!, eltype, empty,
             empty!, filter, filter!, get, get!, getindex, getkey, grow_to!,
             hash, haskey, in, isempty, isequal, iterate, keys, keytype,
             length, map!, merge, merge!, pairs, pop!, promote_rule, push!,
             reduce, setindex!, show, summary, typeinfo_eltype,
             typeinfo_implicit, typeinfo_prefix, valtype, values

using Base: Callable

if VERSION >= v"1.5.0-DEV.182"
    import Base: mergewith, mergewith!
end

if isdefined(Base, :limitrepr)
    using Base: limitrepr
else
    limitrepr(x) = repr(x, context = :limit=>true)
end

include("FlatDict.jl")
include("abstractmultidict.jl")
include("MultiDict.jl")

export FlatDict, AbstractMultiDict, MultiDict


## runtests

using Pkg

const TEST_NCOMBOS_DEFAULT = 10
const TEST_TYPES_DEFAULT = (Nothing, Missing, String, Symbol,
                            Bool, Int8, UInt8, Int32, Int64, BigInt,
                            Float32, Float64, BigFloat)

function runtests(;
                  ncombos::Integer=TEST_NCOMBOS_DEFAULT,
                  types=TEST_TYPES_DEFAULT,
                  special::Bool=true)

    Pkg.test("MoarDicts",
             test_args =
             [ "ncombos=$ncombos",
               "types=" * join(types, ','),
               "special=$special",
             ])
end

end # module
