using Base: hashindex, limitrepr, _unsetindex!, @propagate_inbounds,
    maxprobeshift, maxprobeshift, maxallowedprobe, _tablesz, KeySet,
    dict_with_eltype, isiterable, promote_typejoin, Callable

import Base: length, isempty, setindex!, iterate, push!, merge!, grow_to!,
    empty, getindex, copy, haskey, get!

# + lines ending with a #!! comment are those modified within a function
# otherwise copy-pasted from Base/dict.jl (besides the renaming to MultiDict)
# + when before a function, the whole function might be modifed
# + when #!= before a function, explicitly states that the function wasn't
#   modified

# temporarily inherits from AbstractDict for convenience (e.g. for printing)
mutable struct MultiDict{K,V} <: AbstractMultiDict{K,V}
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

function MultiDict{K,V}(kv) where V where K
    h = MultiDict{K,V}() #!!
    for (k,v) in kv
        push!(h, k => v) #!!
    end
    return h
end

#!!
MultiDict{K,V}(p::Pair) where {K,V} =
    push!(MultiDict{K,V}(), p)

function MultiDict{K,V}(ps::Pair...) where V where K
    h = MultiDict{K,V}() #!!
    sizehint!(h, length(ps))
    for p in ps
        push!(h, p) #!!
    end
    return h
end

MultiDict() = MultiDict{Any,Any}()
MultiDict(kv::Tuple{}) = MultiDict()

#!=
copy(d::MultiDict) = MultiDict(d)

MultiDict(ps::Pair{K,V}...) where {K,V} = MultiDict{K,V}(ps)
MultiDict(ps::Pair...)                  = MultiDict(ps)

#!=
function MultiDict(kv)
    try
        dict_with_eltype((K, V) -> MultiDict{K, V}, kv, eltype(kv))
    catch
        if !isiterable(typeof(kv)) || !all(x->isa(x,Union{Tuple,Pair}),kv)
            throw(ArgumentError("MultiDict(kv): kv needs to be an iterator of tuples or pairs"))
        else
            rethrow()
        end
    end
end

function grow_to!(dest::MultiDict{K, V}, itr) where V where K
    y = iterate(itr)
    y === nothing && return dest
    ((k,v), st) = y
    dest2 = empty(dest, typeof(k), typeof(v))
    push!(dest2, k => v) #!!
    grow_to!(dest2, itr, st)
end

# this is a special case due to (1) allowing both Pairs and Tuples as elements,
# and (2) Pair being invariant. a bit annoying.
function grow_to!(dest::MultiDict{K,V}, itr, st) where V where K
    y = iterate(itr, st)
    while y !== nothing
        (k,v), st = y
        if isa(k,K) && isa(v,V)
            push!(dest, k => v) #!!
        else
            new = empty(dest, promote_typejoin(K,typeof(k)), promote_typejoin(V,typeof(v)))
            merge!(new, dest)
            push!(new, k => v) #!!
            return grow_to!(new, itr, st)
        end
        y = iterate(itr, st)
    end
    return dest
end

empty(d::MultiDict, ::Type{K}, ::Type{V}) where {K, V} = MultiDict{K,V}()

@propagate_inbounds isslotempty(h::MultiDict, i::Int) = h.slots[i] == 0x0
@propagate_inbounds isslotfilled(h::MultiDict, i::Int) = h.slots[i] == 0x1
@propagate_inbounds isslotmissing(h::MultiDict, i::Int) = h.slots[i] == 0x2

#!=
function rehash!(h::MultiDict{K,V}, newsz = length(h.keys)) where V where K
    olds = h.slots
    oldk = h.keys
    oldv = h.vals
    sz = length(olds)
    newsz = _tablesz(newsz)
    h.age += 1
    h.idxfloor = 1
    if h.count == 0
        resize!(h.slots, newsz)
        fill!(h.slots, 0)
        resize!(h.keys, newsz)
        resize!(h.vals, newsz)
        h.ndel = 0
        return h
    end

    slots = zeros(UInt8,newsz)
    keys = Vector{K}(undef, newsz)
    vals = Vector{V}(undef, newsz)
    age0 = h.age
    count = 0
    maxprobe = 0

    for i = 1:sz
        @inbounds if olds[i] == 0x1
            k = oldk[i]
            v = oldv[i]
            index0 = index = hashindex(k, newsz)
            while slots[index] != 0
                index = (index & (newsz-1)) + 1
            end
            probe = (index - index0) & (newsz-1)
            probe > maxprobe && (maxprobe = probe)
            slots[index] = 0x1
            keys[index] = k
            vals[index] = v
            count += 1

            if h.age != age0
                # if `h` is changed by a finalizer, retry
                return rehash!(h, newsz)
            end
        end
    end

    h.slots = slots
    h.keys = keys
    h.vals = vals
    h.count = count
    h.ndel = 0
    h.maxprobe = maxprobe
    @assert h.age == age0

    return h
end

#!=
function sizehint!(d::MultiDict{T}, newsz) where T
    oldsz = length(d.slots)
    if newsz <= oldsz
        # todo: shrink
        # be careful: rehash!() assumes everything fits. it was only designed
        # for growing.
        return d
    end
    # grow at least 25%
    newsz = min(max(newsz, (oldsz*5)>>2),
                max_values(T))
    rehash!(d, newsz)
end

#!=
function empty!(h::MultiDict{K,V}) where V where K
    fill!(h.slots, 0x0)
    sz = length(h.slots)
    empty!(h.keys)
    empty!(h.vals)
    resize!(h.keys, sz)
    resize!(h.vals, sz)
    h.ndel = 0
    h.count = 0
    h.age += 1
    h.idxfloor = 1
    return h
end

#!! almost the same: only index & iter have been moved as function parameters
# get the *first* index where a key is stored, or -1 if not present #!!
function ht_keyindex(h::MultiDict, key, (index, iter)=(hashindex(key, length(h.keys)), 0))
    sz = length(h.keys)
    maxprobe = h.maxprobe
    keys = h.keys

    # precondition: iter <= maxprobe

    @inbounds while true
        if isslotempty(h,index)
            break
        end
        if !isslotmissing(h,index) && (key === keys[index] || isequal(key,keys[index]))
            return index
        end

        index = (index & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end
    return -1
end

#!! new method
# get the index where a key would be inserted
function ht_keyindex_push!(h::MultiDict{K,V}, key) where V where K
    sz = length(h.keys)
    iter = 0
    index = hashindex(key, sz)

    maxallowed = max(maxallowedprobe, sz>>maxprobeshift)
    @inbounds while iter <= maxallowed
        if !isslotfilled(h, index)
            if iter > h.maxprobe
                h.maxprobe = iter
            end
            return index
        end
        index = (index & (sz-1)) + 1
        iter += 1
    end

    rehash!(h, h.count > 64000 ? sz*2 : sz*4)

    return ht_keyindex_push!(h, key)
end

#!=
@propagate_inbounds function _setindex!(h::MultiDict, v, key, index)
    h.slots[index] = 0x1
    h.keys[index] = key
    h.vals[index] = v
    h.count += 1
    h.age += 1
    if index < h.idxfloor
        h.idxfloor = index
    end

    sz = length(h.keys)
    # Rehash now if necessary
    if h.ndel >= ((3*sz)>>2) || h.count*3 > sz*2
        # > 3/4 deleted or > 2/3 full
        rehash!(h, h.count > 64000 ? h.count*2 : h.count*4)
    end
end

#!! new method
function push!(h::MultiDict{K}, p::Pair) where K
    key0, v0 = p
    key = convert(K, key0)
    if !isequal(key, key0)
        throw(ArgumentError("$(limitrepr(key0)) is not a valid key for type $K"))
    end
    _push!(h, v0, key)
end

#!! new method
function _push!(h::MultiDict{K,V}, v0, key::K) where {K,V}
    v = convert(V, v0)
    index = ht_keyindex_push!(h, key)
    @inbounds _setindex!(h, v, key, index)

    h
end

#!=
function get!(default::Callable, h::MultiDict{K,V}, key0) where V where K
    key = convert(K, key0)
    if !isequal(key, key0)
        throw(ArgumentError("$(limitrepr(key0)) is not a valid key for type $K"))
    end
    return get!(default, h, key)
end

# TODO: could be slightly optimzized
#!!
function get!(default::Callable, h::MultiDict{K,V}, key::K) where V where K
    index = ht_keyindex(h, key)

    if index > 0
        h.vals[index]
    else
        v = convert(V, default())
        _push!(h, v, key)
        v
    end
end

# TODO: optimize
function setindex!(h::MultiDict, iter, key)
    delete!(h, key)
    for val in iter
        push!(h, key => val)
    end
    h
end

getindex(h::MultiDict, key) = ValueIterator1(h, key)

#!=
function get(h::MultiDict{K,V}, key, default) where V where K
    index = ht_keyindex(h, key)
    @inbounds return (index < 0) ? default : h.vals[index]::V
end

#!=
haskey(h::MultiDict, key) = ht_keyindex(h, key) >= 0

#!=
function getkey(h::MultiDict{K,V}, key, default) where V where K
    index = ht_keyindex(h, key)
    @inbounds return (index<0) ? default : h.keys[index]::K
end

#!=
function _delete!(h::MultiDict, index)
    @inbounds h.slots[index] = 0x2
    @inbounds _unsetindex!(h.keys, index)
    @inbounds _unsetindex!(h.vals, index)
    h.ndel += 1
    h.count -= 1
    h.age += 1
    return h
end

#!!
function delete!(h::MultiDict, key)
    sz = length(h.keys)
    iter = 0
    maxprobe = h.maxprobe
    index = hashindex(key, sz)
    keys = h.keys

    @inbounds while true
        isslotempty(h, index) && break
        if isslotfilled(h, index) && (key === keys[index] || isequal(key, keys[index]))
            _delete!(h, index)
        end
        index = (index & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end
    h
end

function iterate(v::ValueIterator1{<:MultiDict},
                 (index0, iter) = (hashindex(v.key, length(v.dict.keys)), 0))
    h = v.dict
    key = v.key

    iter > h.maxprobe && return nothing
    index = ht_keyindex(h, key, (index0, iter))
    index == -1 && return nothing

    val = h.vals[index]
    sz = length(h.keys)
    index = (index & (sz-1)) + 1
    iter += (index-index0) & (sz-1)
    return val, (index, iter)
end

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

### from base/abstractdict.jl

#!!
function merge!(d::MultiDict, others::Union{AbstractDict,MultiDict}...)
    for other in others
        for p in other
            push!(d, p)
        end
    end
    return d
end
