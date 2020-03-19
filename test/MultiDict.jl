@testset "MultiDict construction ($A, $B)" for (i, (A, B)) in enumerate(gettypes())
    md = MultiDict{A,B}()
    @test md isa MultiDict{A,B}
    @test isempty(md)
    @test length(md) == 0
    @test eltype(md) == Pair{A,B}
    @test eltype(MultiDict{A,B}) == Pair{A,B}

    let c = rand(1:9)
        md = MultiDict{A,B}(_rand(A) => _rand(B) for _ = 1:c)
        @test length(md) == c
    end

    md = MultiDict{A,B}(_rand(A) => _rand(B))
    @test length(md) == 1
    md = MultiDict{A,B}(_rand(A) => _rand(B), _rand(A) => _rand(B))
    @test length(md) == 2
    @test isequal(md, copy(md))

    md = MultiDict(_rand(A) => _rand(B) for _=1:3)
    @test md isa MultiDict{A,B}
    @test length(md) == 3
    @test isequal(md, copy(md))

    emd = empty(md)
    @test isempty(emd)
    @test keytype(emd) == keytype(md)
    @test valtype(emd) == valtype(md)
    typeof(empty(md, Int)) == MultiDict{keytype(md), Int}
    typeof(empty(md, Int, UInt)) == MultiDict{Int, UInt}

    md = MultiDict(_rand(A) => _rand(B), _rand(A) => _rand(B))
    @test md isa MultiDict{A,B}
    @test length(md) == 2
    @test isequal(md, copy(md))

    if i == 1 # TODO: test more types
        md = MultiDict((1 => 2, 0x1 => 0x2))
        @test md isa MultiDict{Integer,Integer}
        @test length(md) == 2

        md = MultiDict(1 => 2, 0x1 => 0x2)
        @test md isa MultiDict{Integer,Integer}
        @test length(md) == 2
    end
    if i == 1
        for md = (MultiDict(), MultiDict(()))
            @test md isa MultiDict{Any,Any}
            @test isempty(md)
        end
    end
end

@testset "MultiDict iterate ($A, $B)" for (A, B) in gettypes()
    md = MultiDict{A,B}()
    P = eltype(md)

    @test collect(md) == P[]

    v = [_rand(A) => _rand(B) for _=1:rand(1:40)]
    md = MultiDict(v)
    @test length(md) == length(v)
    @test isequal(Set(md), Set(v))
end

@testset "MultiDict update ($A, $B)" for (A, B) in gettypes()
    md = MultiDict{A,B}()

    if A <: Number && B <: Number
        push!(md, 0 => 0)
        push!(md, 0 => 1)
        push!(md, 1 => 1)

        a = sort!(collect(md))
        @test a == Pair{A,B}[0 => 0, 0 => 1, 1 => 1]

        # test that rehash! works
        for i = 4:100
            push!(md, 0 => 0)
        end
        @test length(md) == 100

        @test !isempty(md)
        empty!(md)
        @test isempty(md)
    end

    ## delete!
    a, a2, b, c = _rand.((A, A, B, B))

    md = MultiDict(a => b, a => c, a2 => b, a2 => c, a => b)
    md2 = delete!(md, a2)
    @test md2 === md
    if isequal(a, a2)
        @test isempty(md)
    else
        for _=1:2
            @test length(md) == 3
            @test isempty(md[a2])
            @test length(collect(md[a])) == 3
            delete!(md, a2) # should have no effect
        end
    end
    delete!(md, a)
    @test isempty(md)
    for _=1:100
        push!(md, a => b)
    end
    @test length(md) == 100
    delete!(md, a)
    @test isempty(md)

    ## setindex!
    md = MultiDict{A,B}()
    md[a] = (b, c)
    @test length(md) == 2
    @test issetequal(md[a], (b, c))
    md[a] = (c,)
    @test length(md) == 1
    @test issetequal(md[a], (c,))
    md[a2] = (b, c)
    if isequal(a, a2)
        @test length(md) == 2
        @test length(Set(keys(md))) == 1
    else
        @test length(md) == 3
        @test length(Set(keys(md))) == 2
    end
    @test issetequal(md[a2], (b, c))

    ## get!
    a, a2, a3, b, c, d = _rand.((A, A, A, B, B, B))

    md = MultiDict(a => b, a2 => c)
    g = get!(md, a, :def)
    if isequal(a, a2)
        @test isequal(g, b) || isequal(g, c)
    else
        @test isequal(g, b)
    end
    if length(Set([a, a2, a3])) == 3
        f = get!(md, a3, d)
        @test isequal(f, d)
        @test length(collect(md[a3])) == 1
        @test isequal(first(md[a3]), d)
    end
    md = MultiDict(a => b)
    v = get!(() -> c, md, a2)
    if isequal(a, a2)
        @test isequal(v, b)
    else
        @test isequal(v, c)
    end

    ## pop!
    a, b, c, x, y, z = _rand.((A, A, A, B, B, B))
    md = MultiDict(a => x, a => y, b => z)
    avals = Set([x, y])
    isequal(a, b) && push!(avals, z)

    u = pop!(md, a, :def)
    @test u in avals
    @test u !== :def # redundant test, as :def can't be generated from _rand(Symbol)
    @test length(md) == 2

    v = pop!(md, a)
    @test v in avals
    @test !isequal(v, u) || isequal(x, y) || isequal(a, b)
    @test Set([u, v]) == Set([x, y]) || isequal(a, b)
    @test length(md) == 1
    if !isequal(a, b)
        @test !in(a => x, md, isequal)
        @test !in(a => y, md, isequal)
        @test_throws KeyError pop!(md, a)
        @test pop!(md, a, :def) === :def
        w = pop!(md)
        @test w === (b => z)
        @test isempty(md)
    else
        @test in(pop!(md, a), avals)
        @test isempty(md)
    end
    @test_throws ArgumentError pop!(md)

    md = MultiDict(a => x, a => y, b => z)
    md2 = copy(md)
    @test in(pop!(md), md2, isequal)
    @test in(pop!(md), md2, isequal)
    @test in(pop!(md), md2, isequal)
    @test isempty(md)

    ## copy!
    for md in (MultiDict(a => x, a => y, b => z), Dict(a => x, b => z))
        for md2 in (MultiDict(b => x), Dict(b => x))
            r = copy!(md2, md)
            @test md2 === r
            if (md isa MultiDict) == (md2 isa MultiDict) || md2 isa MultiDict
                @test isequal(md2, md)
            end
        end
    end
end

@testset "MultiDict query ($A, $B)" for (A, B) in gettypes()
    md = MultiDict{A,B}()

    a, a2, b, c = _rand.((A, A, B, B))

    @test get(md, a, :def) === :def
    @test isempty(md)

    push!(md, a => b)

    @test get(md, a, :def) === b
    @test !isempty(md)
    @test length(md) == 1
    @test get(md, a, :def) === b
    @test in(a => b, md, isequal)
    @test haskey(md, a)
    @test haskey(md, a2) == isequal(a, a2)
    @test isequal(getkey(md, a, :def), a)
    @test isequal(getkey(md, a2, :def), isequal(a, a2) ? a2 : :def)

    if B !== Missing
        @test (a => b) in md
    else
        @test ((a => b) in md) === missing
    end

    push!(md, a => c)
    @test in(a => c, md, isequal)
    if B !== Missing
        @test (a => c) in md
    else
        @test ((a => c) in md) === missing
    end
    # can't use get(...) ∈ (b, c) when missing is involved
    @test any(isequal(get(md, a, :def)), (b, c))
    @test isequal(getkey(md, a, :def), a)

    if !isequal(a, a2)
        @test get(md, a2, :def) === :def
        @test getkey(md, a2, :def) === :def
    end

    mda = collect(md[a])
    @test eltype(mda) == valtype(md)
    @test length(mda) == 2
    @test issetequal(mda, [b, c])
    if !isequal(a, a2)
        @test isempty(collect(md[a2]))
    end

    @test_throws ErrorException 1 in md

    push!(md, a2 => c)
    @test haskey(md, a)
    @test haskey(md, a2)

    ## pairs
    md = MultiDict(_rand(A) => _rand(B) for _=1:9)
    md2 = copy(md)
    @test pairs(md) === md
    @test isequal(md, md2) # check that `pairs` didn't mutate md

    ## in(_, keys(md))
    kv = first(md) # TODO: use rand instead of first
    @test first(kv) in keys(md)
end

@testset "MultiDict merge[!] ($A, $B)" for (A, B) in gettypes()
    ## merge!
    let (a, b) = _rand(A) => _rand(B)
        (c, d) = _rand(A) => _rand(B)
        for dd = (Dict(c => d), MultiDict(c => d))
            for md = (Dict(a => b), MultiDict(a => b))
                md3 = merge(md, dd)
                md2 = merge!(md, dd)
                @test md2 === md
                if md isa AbstractMultiDict
                    @test isequal(md2, md3)
                else
                    @test issubset(md2, Set(md3)) # Set for handling missing
                end
                if md isa AbstractMultiDict
                    @test length(md) == 2
                    @test in(a => b, md, isequal)
                    @test in(c => d, md, isequal)
                else
                    if isequal(a, c)
                        @test length(md) == 1
                        @test in(a => b, md, isequal) || in(c => d, md, isequal)
                    else
                        @test length(md) == 2
                        @test in(a => b, md, isequal)
                        @test in(c => d, md, isequal)
                    end
                end
            end
        end

        dd = Dict(c => d)
        md = MultiDict(a => b)
        md2 = merge(md, md)
        merge!(md, copy(md))
        @test isequal(md, md2)
        @test isequal(collect(md[a]), [b, b])
        dd2 = merge(dd, md)
        merge!(dd, md)
        @test issubset(dd, Set(dd2))
        if isequal(a, c)
            @test length(dd) == 1
            @test dd[a] ∈ Set([b, d])
        else
            cdd = collect(dd)
            @test isequal(cdd, [c => d, a => b]) ||
                isequal(cdd, [a => b, c => d])
        end
        # md = a => b, a => b
        # dd = c => d, a => b
        md2 = merge(md, dd, dd)
        merge!(md, dd, dd)
        @test isequal(md, md2)
        @test length(collect(md[a])) == 4
        if isequal(a, c)
            @test length(md) == 4
            @test Set(md[a]) ⊆ Set([b, d])
        else
            @test length(md) == 6
            @test isequal(Set(md[a]), Set([b]))
        end
    end
end

@testset "MultiDict filter[!] ($A, $B)" for (A, B) in gettypes()
    md0 = MultiDict(_rand(A) => _rand(B) for _=1:9)
    len = length(md0)
    ks = shuffle!(collect(keys(md0)))
    vs = shuffle!(collect(values(md0)))
    for _ = 1:len
        k = pop!(ks)
        md = copy(md0)
        md1 = filter!(kv -> !isequal(k, first(kv)), md)
        md2 = filter( kv -> !isequal(k, first(kv)), md0)
        @test md1 === md
        @test length(md1) == length(md2) < length(md0) == len
        @test isequal(md1, md2)

        v = pop!(vs)
        md = copy(md0)
        md1 = filter!(kv -> !isequal(v, last(kv)), md)
        md2 = filter( kv -> !isequal(v, last(kv)), md0)
        @test md1 === md
        @test length(md1) == length(md2) < length(md0) == len
        @test isequal(md1, md2)
    end
end

@testset "MultiDict setindex!/getindex" begin
    md = MultiDict{Int,Int}(1=>2, 1=>2)
    @test collect(md[1]) == [2, 2]
    @test eltype(md[1]) == Int
    @test collect(md[0x1]) == [2, 2]
    @test collect(md[0]) == Int[]
    @test collect(md[false]) == Int[]

    ## md[x, y, z]
    md = MultiDict()
    md[1, 2, 3] = (1, 2)
    @test haskey(md, (1, 2, 3))
    @test md[1, 2, 3] == md[(1, 2, 3)]
    @test Set(md[1, 2, 3]) == Set([1, 2])
end

@testset "MultiDict isequal/==/hash" begin
    md = MultiDict(1 => 2, 1 => 2)
    @test isequal(md, md)
    @test isequal(md, copy(md))
    @test md == md
    @test md == copy(md)
    @test hash(md) == hash(md) == hash(copy(md))
    @test md != Dict(md)
    @test !isequal(md, Dict(md))

    md = MultiDict(1 => missing)
    for x = (md, copy(md), Dict(md))
        @test isequal(md, x)
        @test ismissing(md == x)
        @test hash(md) == hash(x)
    end

    md = MultiDict(1 => [missing])
    for x = (md, copy(md), Dict(md))
        @test isequal(md, x)
        @test ismissing(md == x)
        @test hash(md) == hash(x)
    end

    md = MultiDict(1 => NaN)
    for x = (md, copy(md), Dict(md))
        @test isequal(md, x)
        @test md != x
        @test hash(md) == hash(x)
    end
end

@testset "MultiDict show" begin
    md = MultiDict{Int,Int}()
    push!(md, 1 => 2)
    if VERSION > v"1.4.0-"
        @test showstr(md) == "MultiDict(1 => 2)"
        @test replstr(md) == "MultiDict{Int64,Int64} with 1 entry:\n  1 => 2"
    else
        @test occursin("MultiDict", showstr(md))
        @test occursin("MultiDict", replstr(md))
    end

    md = MultiDict{UInt8,UInt8}()
    push!(md, 0x1 => 0x2)
    push!(md, 0x3 => 0x4)

    if VERSION > v"1.4.0-"
        @test showstr(md) == "MultiDict{UInt8,UInt8}(0x03 => 0x04,0x01 => 0x02)"
        @test replstr(md) ==
            "MultiDict{UInt8,UInt8} with 2 entries:\n" *
            "  0x03 => 0x04\n" *
            "  0x01 => 0x02"

        md = MultiDict{Integer,Integer}(1=>2)
        @test showstr(md) == "MultiDict{Integer,Integer}(1 => 2)"
    else
        @test occursin("MultiDict", showstr(md))
        @test occursin("MultiDict", replstr(md))
    end
end

@testset "MultiDict keys/values" begin
    md = MultiDict{Int,UInt}(1=>2, 1=>3, 2=>3)

    @test keytype(md) == Int
    @test valtype(md) == UInt

    ks = keys(md)
    vs = values(md)

    @test eltype(ks) == Int
    @test eltype(vs) == UInt
    @test length(ks) == 3
    @test length(vs) == 3
    @test !isempty(ks)
    @test !isempty(vs)
    @test sort!(collect(ks)) == [1, 1, 2]
    @test sort!(collect(vs)) == [2, 3, 3]
end
