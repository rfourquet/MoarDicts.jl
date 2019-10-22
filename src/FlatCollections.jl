module FlatCollections

import Base: delete!, empty!, get, get!, isempty, iterate, length, pop!, setindex!

if isdefined(Base, :limitrepr)
    using Base: limitrepr
else
    limitrepr(x) = repr(x, context = :limit=>true)
end

include("FlatDict.jl")

export FlatDict

end # module
