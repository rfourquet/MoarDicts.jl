module MoarDicts

import Base: delete!, empty!, get, get!, getkey, isempty, iterate, length, pop!, setindex!

if isdefined(Base, :limitrepr)
    using Base: limitrepr
else
    limitrepr(x) = repr(x, context = :limit=>true)
end

include("FlatDict.jl")
include("abstractmultidict.jl")
include("MultiDict.jl")

export FlatDict, MultiDict


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
