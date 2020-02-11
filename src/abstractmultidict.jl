import Base: show, summary, typeinfo_prefix, typeinfo_implicit, typeinfo_eltype, keytype, valtype
using Base: show_circular, _truncate_at_width_or_chars, showarg

abstract type AbstractMultiDict{K,V} end

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

keytype(::Type{<:AbstractMultiDict{K,V}}) where {K,V} = K
keytype(a::AbstractMultiDict) = keytype(typeof(a))
valtype(::Type{<:AbstractMultiDict{K,V}}) where {K,V} = V
valtype(a::AbstractMultiDict) = valtype(typeof(a))

#!=
function summary(io::IO, t::AbstractMultiDict)
    n = length(t)
    showarg(io, t, true)
    print(io, " with ", n, (n==1 ? " entry" : " entries"))
end

## from base/show.jl

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
