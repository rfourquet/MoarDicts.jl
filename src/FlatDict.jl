## constants

const MAX_NEWS_SEARCH = 16


## construction

NewPair{K,V} = Union{Pair{K,Some{V}},
                     Pair{K,Nothing}}

struct FlatDict{K,V} <: AbstractDict{K,V}
    keys::Vector{K}
    vals::Vector{V}
    news::Vector{NewPair{K,V}}
    temp::Vector{NewPair{K,V}}

    FlatDict{K,V}() where {K,V} =
        new(Vector{K}(), Vector{V}(),
            Vector{NewPair{K,V}}(), Vector{NewPair{K,V}}())
end


## internal: resort! & makekey & mapping & getval

function resort!(fd::FlatDict)
    keys, vals, news = fd.keys, fd.vals, fd.news
    isempty(news) && return fd

    sort!(news, 1, length(news), Base.MergeSort, Base.Order.By(first), fd.temp)
    ikey, inew = length.((keys, news))
    idst = ikey + inew
    resize!(keys, idst)
    resize!(vals, idst)

    while true
        if inew == 0
            while ikey != 0
                # TODO: skip loop if indexes the same
                keys[idst], vals[idst] = keys[ikey], vals[ikey]
                idst -= 1
                ikey -= 1
            end
            break
        elseif ikey == 0
            while inew != 0
                newk, newv = news[inew]
                if newv !== nothing
                    keys[idst], vals[idst] = newk, something(newv)
                    idst -= 1
                end
                inew -= 1
                while inew > 0 && isequal(first(news[inew+1]),
                                          first(news[inew]))
                    inew -= 1
                end
            end
            break
        else
            if isless(first(news[inew]), keys[ikey])
                keys[idst], vals[idst] = keys[ikey], vals[ikey]
                idst -= 1
                ikey -= 1
            else
                newk, newv = news[inew]
                if isequal(newk, keys[ikey])
                    ikey -= 1 # keys[ikey] overwritten
                end
                if newv !== nothing
                    keys[idst], vals[idst] = newk, something(newv)
                    idst -= 1
                end
                inew -= 1
                while inew > 0 && isequal(first(news[inew+1]),
                                          first(news[inew]))
                    inew -= 1
                end
            end
        end
    end

    Base._deletebeg!(keys, idst)
    Base._deletebeg!(vals, idst)
    empty!(news)
    fd
end

function mayberesort!(fd::FlatDict)
    length(fd.news) > MAX_NEWS_SEARCH && resort!(fd)
    fd
end

# convert key0 to a valid key for flat dict
function makekey(::FlatDict{K}, key0) where K
    key = convert(K, key0)
    isequal(key, key0) ||
        throw(ArgumentError("$(limitrepr(key0)) is not a valid key for type $K"))
    key
end

# errors must be deterministic, and not depend on whether binary search
# occurs (where a non-comparable key, e.g. nothing, would lead to an error),
# which depends on whether resort! has been called;
# so mapping accepts only a key of the correct type, and makekey must be
# called first by the caller, to error early and consistently
@inline function mapping(fd::FlatDict{K}, key::K) where K
    mayberesort!(fd)
    idx = findlast(kv -> isequal(key, first(kv)), fd.news)
    @inbounds if idx !== nothing
        key, val = fd.news[idx]
        val === nothing ?
            nothing :
            key => something(val)
    else
        idx = searchsortedfirst(fd.keys, key)
        idx <= length(fd.keys) && isequal(fd.keys[idx], key) ?
            fd.keys[idx] => fd.vals[idx] :
            nothing
    end
end

function getval(fd::FlatDict, key)
    kv = mapping(fd, key)
    kv === nothing ?
        nothing :
        Some(last(kv))
end

## update

_setindex!(fd::FlatDict{K}, val, key::K) where {K} =
    push!(fd.news, key => Some(convert(valtype(fd), val)))

function setindex!(fd::FlatDict, val, key)
    _setindex!(fd, val, makekey(fd, key))
    fd
end

function pop!(fd::FlatDict)
    resort!(fd)
    pop!(fd.keys) => pop!(fd.vals)
end

function pop!(fd::FlatDict, key)
    key = makekey(fd, key) # save some search when not a valid key
    val = getval(fd, key)
    if val === nothing
        throw(KeyError(key))
    else
        delete!(fd, key)
        something(val)
    end
end

function pop!(fd::FlatDict, key, default)
    key = makekey(fd, key)
    val = getval(fd, key)
    if val === nothing
        default
    else
        delete!(fd, key)
        something(val)
    end
end

function delete!(fd::FlatDict, key)
    push!(fd.news, makekey(fd, key) => nothing)
    fd
end

function empty!(fd::FlatDict)
    empty!(fd.keys)
    empty!(fd.vals)
    empty!(fd.news)
    fd
end


## query

_length(fd::FlatDict) = length(fd.keys)

length(fd::FlatDict) = _length(resort!(fd))

isempty(fd::FlatDict) = length(fd) == 0

get(fd::FlatDict, key, default) =
    something(getval(fd, makekey(fd, key)), Some(default))

## iterate

function iterate(d::FlatDict, state=1)
    resort!(d)
    state > _length(d) && return nothing
    d.keys[state] => d.vals[state], state+1
end
