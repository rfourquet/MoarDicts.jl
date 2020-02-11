using Base: hashindex, limitrepr, _unsetindex!, @propagate_inbounds,
    maxprobeshift, maxprobeshift, maxallowedprobe, _tablesz, KeySet,
    ValueIterator

import Base: length, isempty, setindex!, iterate, push!

# + lines ending with a #!! comment are those modified within a function
# otherwise copy-pasted from Base/dict.jl (besides the renaming to MultiDict)
# + when before a function, the whole function might be modifed
# + when #!= before a function, explicitly states that the function wasn't
#   modified

# temporarily inherits from AbstractDict for convenience (e.g. for printing)
mutable struct MultiDict{K,V} <: AbstractDict{K,V}
    slots::Array{UInt8,1}
    keys::Array{K,1}
    vals::Array{V,1}
    ndel::Int
    count::Int
    age::UInt
    idxfloor::Int  # an index <= the indices of all used slots
    maxprobe::Int

    function MultiDict{K,V}() where V where K
        n = 16
        new(zeros(UInt8,n), Vector{K}(undef, n), Vector{V}(undef, n), 0, 0, 0, 1, 0)
    end
    function MultiDict{K,V}(d::MultiDict{K,V}) where V where K
        new(copy(d.slots), copy(d.keys), copy(d.vals), d.ndel, d.count, d.age,
            d.idxfloor, d.maxprobe)
    end
    function MultiDict{K, V}(slots, keys, vals, ndel, count, age, idxfloor, maxprobe) where {K, V}
        new(slots, keys, vals, ndel, count, age, idxfloor, maxprobe)
    end
end

@propagate_inbounds isslotempty(h::MultiDict, i::Int) = h.slots[i] == 0x0
@propagate_inbounds isslotfilled(h::MultiDict, i::Int) = h.slots[i] == 0x1
@propagate_inbounds isslotmissing(h::MultiDict, i::Int) = h.slots[i] == 0x2

#!=
function skip_deleted(h::MultiDict, i)
    L = length(h.slots)
    for i = i:L
        @inbounds if isslotfilled(h,i)
            return  i
        end
    end
    return 0
end

#!=
function skip_deleted_floor!(h::MultiDict)
    idx = skip_deleted(h, h.idxfloor)
    if idx != 0
        h.idxfloor = idx
    end
    idx
end

#!=
@propagate_inbounds _iterate(t::MultiDict{K,V}, i) where {K,V} =
    i == 0 ? nothing :
    (Pair{K,V}(t.keys[i],t.vals[i]), i == typemax(Int) ? 0 : i+1)

#!=
@propagate_inbounds function iterate(t::MultiDict)
    _iterate(t, skip_deleted_floor!(t))
end

#!=
@propagate_inbounds iterate(t::MultiDict, i) = _iterate(t, skip_deleted(t, i))

isempty(t::MultiDict) = (t.count == 0)
length(t::MultiDict) = t.count
