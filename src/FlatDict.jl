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


## resort!

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

## update

_setindex!(fd::FlatDict, val, key) = push!(fd.news, key => Some(val))

function setindex!(fd::FlatDict, val, key)
    _setindex!(fd, val, key)
end


## query

_length(fd::FlatDict) = length(fd.keys)

length(fd::FlatDict) = _length(resort!(fd))

isempty(fd::FlatDict) = length(fd) == 0

function get(fd::FlatDict, key, default)
    idx = findlast(kv -> isequal(key, first(kv)), fd.news)
    if idx !== nothing
        val = last(fd.news[idx])
        val === nothing ? default : something(val)
    else
        idx = searchsortedfirst(fd.keys, key)
        idx <= length(fd.keys) && isequal(fd.keys[idx], key) ?
            fd.vals[idx] :
            default
    end
end

## iterate

function iterate(d::FlatDict, state=1)
    resort!(d)
    state > _length(d) && return nothing
    d.keys[state] => d.vals[state], state+1
end
