using Base: _truncate_at_width_or_chars, _tt2, hasha_seed, secret_table_token,
            show_circular, show_vector, showarg

abstract type AbstractMultiDict{K,V} end
abstract type AbstractMultiSet{K} end

const Associative = Union{AbstractDict,AbstractMultiDict}

eltype(::Type{<:AbstractMultiSet{K}}) where {K} = K

# iterates values for 1 given key
struct ValueIterator1{T<:AbstractMultiDict,K}
    dict::T
    key::K
end

Base.IteratorSize(::Type{<:ValueIterator1}) = Base.SizeUnknown()

eltype(::Type{<:ValueIterator1{T}}) where {T} = valtype(T)

show(io::IO, iter::ValueIterator1) =
    # set :limit to false as length(iter) is not defined
    show_vector(IOContext(io, :limit => false), iter, '{', '}')

## from base/dict.jl

#!=
function show(io::IO, t::AbstractMultiDict{K,V}) where V where K
    recur_io = IOContext(io, :SHOWN_SET => t,
                             :typeinfo => eltype(t))

    limit::Bool = get(io, :limit, false)
    # show in a Julia-syntax-like form: Dict(k=>v, ...)
    print(io, typeinfo_prefix(io, t))
    print(io, '(')
    if !isempty(t) && !show_circular(io, t)
        first = true
        n = 0
        for pair in t
            first || print(io, ',')
            first = false
            show(recur_io, pair)
            n+=1
            limit && n >= 10 && (print(io, "…"); break)
        end
    end
    print(io, ')')
end

## from base/abstractdict.jl

#!!
in(p::Pair, h::AbstractMultiDict, valcmp=(==)) =
    any(valcmp(last(p)), h[first(p)])

function in(p, a::AbstractMultiDict)
    error("""AbstractMultiDict collections only contain Pairs;
             Either look for e.g. A=>B instead, or use the `keys` or `values`
             function if you are looking for a key or value respectively.""")
end

#!=
function summary(io::IO, t::AbstractMultiDict)
    n = length(t)
    showarg(io, t, true)
    print(io, " with ", n, (n==1 ? " entry" : " entries"))
end

struct KeyMultiSet{K, T <: AbstractMultiDict{K}} <: AbstractMultiSet{K}
    dict::T
end

struct ValueIterator{T<:AbstractMultiDict}
    dict::T
end

#!=
function summary(io::IO, iter::T) where {T<:Union{KeyMultiSet,ValueIterator}}
    print(io, T.name, " for a ")
    summary(io, iter.dict)
end

show(io::IO, iter::Union{KeyMultiSet,ValueIterator}) = show_vector(io, iter)

length(v::Union{KeyMultiSet,ValueIterator}) = length(v.dict)
isempty(v::Union{KeyMultiSet,ValueIterator}) = isempty(v.dict)

eltype(::Type{ValueIterator{D}}) where {D} = _tt2(eltype(D))

function iterate(v::Union{KeyMultiSet,ValueIterator}, state...)
    y = iterate(v.dict, state...)
    y === nothing && return nothing
    return (y[1][isa(v, KeyMultiSet) ? 1 : 2], y[2]) #!!
end

keys(a::AbstractMultiDict) = KeyMultiSet(a)
values(a::AbstractMultiDict) = ValueIterator(a)

pairs(a::AbstractMultiDict) = a

empty(a::AbstractMultiDict) = empty(a, keytype(a), valtype(a))
empty(a::AbstractMultiDict, ::Type{V}) where {V} = empty(a, keytype(a), V)

#!!
function merge!(d::Associative, others::Associative...)
    for other in others
        for p in other
            push!(d, p)
        end
    end
    return d
end

keytype(::Type{<:AbstractMultiDict{K,V}}) where {K,V} = K
keytype(a::AbstractMultiDict) = keytype(typeof(a))
valtype(::Type{<:AbstractMultiDict{K,V}}) where {K,V} = V
valtype(a::AbstractMultiDict) = valtype(typeof(a))

#!! very similar, but without depwarn
function filter(f, d::AbstractMultiDict)
    # don't just do filter!(f, copy(d)): avoid making a whole copy of d
    df = empty(d)
    for pair in d
        if f(pair)
            push!(df, pair) #!!
        end
    end
    df
end

#!=
function eltype(::Type{<:AbstractMultiDict{K,V}}) where {K,V}
    if @isdefined(K)
        if @isdefined(V)
            return Pair{K,V}
        else
            return Pair{K}
        end
    elseif @isdefined(V)
        return Pair{k,V} where k
    else
        return Pair
    end
end

#!=
function isequal(l::Associative, r::Associative)
    l === r && return true
    length(l) != length(r) && return false
    for pair in l
        if !in(pair, r, isequal)
            return false
        end
    end
    true
end

#!=
function ==(l::Associative, r::Associative)
    length(l) != length(r) && return false
    anymissing = false
    for pair in l
        isin = in(pair, r)
        if ismissing(isin)
            anymissing = true
        elseif !isin
            return false
        end
    end
    return anymissing ? missing : true
end

#!=
function hash(a::AbstractMultiDict, h::UInt)
    hv = hasha_seed
    for (k,v) in a
        hv ⊻= hash(k, hash(v))
    end
    hash(hv, h)
end

get!(t::AbstractMultiDict, key, default) = get!(() -> default, t, key)


## from base/show.jl

#!=
function show(io::IO, ::MIME"text/plain", iter::Union{KeyMultiSet,ValueIterator})
    summary(io, iter)
    isempty(iter) && return
    print(io, ". ", isa(iter,KeyMultiSet) ? "Keys" : "Values", ":") #!!
    limit::Bool = get(io, :limit, false)
    if limit
        sz = displaysize(io)
        rows, cols = sz[1] - 3, sz[2]
        rows < 2 && (print(io, " …"); return)
        cols < 4 && (cols = 4)
        cols -= 2 # For prefix "  "
        rows -= 1 # For summary
    else
        rows = cols = typemax(Int)
    end

    for (i, v) in enumerate(iter)
        print(io, "\n  ")
        i == rows < length(iter) && (print(io, "⋮"); break)

        if limit
            str = sprint(show, v, context=io, sizehint=0)
            str = _truncate_at_width_or_chars(str, cols, "\r\n")
            print(io, str)
        else
            show(io, v)
        end
    end
end

#!=
function show(io::IO, ::MIME"text/plain", t::AbstractMultiDict{K,V}) where {K,V}
    # show more descriptively, with one line per key/value pair
    recur_io = IOContext(io, :SHOWN_SET => t)
    limit::Bool = get(io, :limit, false)
    if !haskey(io, :compact)
        recur_io = IOContext(recur_io, :compact => true)
    end

    summary(io, t)
    isempty(t) && return
    print(io, ":")
    show_circular(io, t) && return
    if limit
        sz = displaysize(io)
        rows, cols = sz[1] - 3, sz[2]
        rows < 2   && (print(io, " …"); return)
        cols < 12  && (cols = 12) # Minimum widths of 2 for key, 4 for value
        cols -= 6 # Subtract the widths of prefix "  " separator " => "
        rows -= 1 # Subtract the summary

        # determine max key width to align the output, caching the strings
        ks = Vector{String}(undef, min(rows, length(t)))
        vs = Vector{String}(undef, min(rows, length(t)))
        keylen = 0
        vallen = 0
        for (i, (k, v)) in enumerate(t)
            i > rows && break
            ks[i] = sprint(show, k, context=recur_io, sizehint=0)
            vs[i] = sprint(show, v, context=recur_io, sizehint=0)
            keylen = clamp(length(ks[i]), keylen, cols)
            vallen = clamp(length(vs[i]), vallen, cols)
        end
        if keylen > max(div(cols, 2), cols - vallen)
            keylen = max(cld(cols, 3), cols - vallen)
        end
    else
        rows = cols = typemax(Int)
    end

    for (i, (k, v)) in enumerate(t)
        print(io, "\n  ")
        if i == rows < length(t)
            print(io, rpad("⋮", keylen), " => ⋮")
            break
        end

        if limit
            key = rpad(_truncate_at_width_or_chars(ks[i], keylen, "\r\n"), keylen)
        else
            key = sprint(show, k, context=recur_io, sizehint=0)
        end
        print(recur_io, key)
        print(io, " => ")

        if limit
            val = _truncate_at_width_or_chars(vs[i], cols - keylen, "\r\n")
            print(io, val)
        else
            show(recur_io, v)
        end
    end
end

## from base/arrayshow.jl

typeinfo_eltype(typeinfo::Type{<:AbstractMultiDict{K,V}}) where {K,V} = eltype(typeinfo)

# similar to typeinfo_implicit(::Type{<:AbstractDict})
function typeinfo_implicit(::Type{T}) where T <: AbstractMultiDict
    return isconcretetype(T) &&
        typeinfo_implicit(keytype(T)) && typeinfo_implicit(valtype(T))
end

# similar to typeinfo_prefix(::Type{<:AbstractDict})
function typeinfo_prefix(io::IO, X::AbstractMultiDict)
    typeinfo = get(io, :typeinfo, Any)::Type
    if !(X isa typeinfo)
        typeinfo = Any
    end

    # what the context already knows about the eltype of X:
    eltype_ctx = typeinfo_eltype(typeinfo)
    eltype_X = eltype(X)

    if eltype_X == eltype_ctx || (!isempty(X) && typeinfo_implicit(keytype(X)) && typeinfo_implicit(valtype(X)))
        string(typeof(X).name)
    else
        string(typeof(X))
    end
end
