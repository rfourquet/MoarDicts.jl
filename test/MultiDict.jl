@testset "MultiDict construction ($A, $B)" for (i, (A, B)) in enumerate(gettypes())
    md = MultiDict{A,B}()
    @test md isa MultiDict{A,B}
    @test isempty(md)
    @test length(md) == 0

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
