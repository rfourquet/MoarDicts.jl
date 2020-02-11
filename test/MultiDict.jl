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

    md = MultiDict(_rand(A) => _rand(B) for _=1:3)
    @test md isa MultiDict{A,B}
    @test length(md) == 3

    md = MultiDict(_rand(A) => _rand(B), _rand(A) => _rand(B))
    @test md isa MultiDict{A,B}
    @test length(md) == 2

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

    push!(md, a => c)
    # can't use get(...) ∈ (b, c) when missing is involved
    @test any(isequal(get(md, a, :def)), (b, c))

    if !isequal(a, a2)
        @test get(md, a2, :def) === :def
    end
end

@testset "show" begin
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
