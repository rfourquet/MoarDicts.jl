module FlatCollections

import Base: get, isempty, iterate, length, setindex!

if isdefined(Base, :limitrepr)
    using Base: limitrepr
else
    limitrepr(x) = repr(x, context = :limit=>true)
end

include("FlatDict.jl")

export FlatDict

end # module
