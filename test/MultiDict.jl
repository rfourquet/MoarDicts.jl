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

    ## merge!
    let (a, b) = _rand(A) => _rand(B)
        (c, d) = _rand(A) => _rand(B)
        for dd = (Dict(c => d), MultiDict{A,B}(c => d))
            md = MultiDict{A,B}(a => b)
            md2 = merge!(md, Dict(c => d))
            @test md2 === md
            r = collect(md)
            @test length(md) == 2
            if A !== Missing && B !== Missing
                @test (a => b) in r
                @test (c => d) in r
            end
        end
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
end

@testset "MultiDict getindex" begin
    md = MultiDict{Int,Int}(1=>2, 1=>2)
    @test collect(md[1]) == [2, 2]
    @test eltype(md[1]) == Int
    @test collect(md[0x1]) == [2, 2]
    @test collect(md[0]) == Int[]
    @test collect(md[false]) == Int[]
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
