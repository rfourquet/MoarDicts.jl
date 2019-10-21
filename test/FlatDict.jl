@testset "construction ($A, $B)" for (A, B) in gettypes()
    @test FlatDict{A,B}() isa FlatDict{A,B}
end

@testset "update ($A, $B)" for (A, B) in gettypes()
    fd = FlatDict{A,B}()
    a, b = _rand.((A, B))
    fd[a] = b
    if B !== Missing
        @test (a => b) in fd
        @test fd[a] === b
    else
        @test missing === ((a => b) in fd)
        @test fd[a] === b === missing
    end
end

@testset "query ($A, $B)" for (A, B) in gettypes()
    fd = FlatDict{A,B}()

    @test length(fd) == 0
    @test isempty(fd)

    a, b = _rand.((A, B))
    fd[a] = b

    @test get(fd, a, :def) === b
    @test !isempty(fd)
    @test length(fd) == 1
    # test again, length triggered a `resort!`
    @test get(fd, a, :def) === b
    @test length(fd) == 1

    fd[a] = b # no-op
    @test length(fd) == 1

    if !Base.issingletontype(A)
        while true
            c = _rand(A)
            isequal(a, c) && continue
            @test get(fd, c, :def) === :def

            fd[c] = b
            @test get(fd, c, :def) === b
            @test length(fd) == 2
            @test get(fd, c, :def) === b

            break
        end
    end
end

@testset "iterate ($A, $B)" for (A, B) in gettypes()
    fd = FlatDict{A,B}()
    P = eltype(fd)

    @test collect(fd) == P[]

    a, b = _rand.((A, B))
    fd[a] = b

    @test isequal(collect(fd), P[a => b])

    a2, b2 = _rand.((A, B))
    fd[a2] = b2

    vec = collect(fd)
    if isless(a, a2)
        @test isequal(vec, P[a => b, a2 => b2])
    elseif isless(a2, a)
        @test isequal(vec, P[a2 => b2, a => b])
    else
        @test isequal(a, a2)
        @test isequal(vec, P[a => b2])
    end
end

@testset "show" begin
    fd = FlatDict{Int,Int}()
    fd[1] = 2
    if VERSION > v"1.4.0-"
        @test showstr(fd) == "FlatDict(1 => 2)"
        @test replstr(fd) == "FlatDict{Int64,Int64} with 1 entry:\n  1 => 2"
    else
        @test occursin("FlatDict", showstr(fd))
        @test occursin("FlatDict", replstr(fd))
    end

    fd = FlatDict{UInt8,UInt8}()
    fd[0x1] = 0x2
    fd[0x3] = 0x4

    if VERSION > v"1.4.0-"
        @test showstr(fd) == "FlatDict{UInt8,UInt8}(0x01 => 0x02,0x03 => 0x04)"
        @test replstr(fd) ==
            "FlatDict{UInt8,UInt8} with 2 entries:\n" *
            "  0x01 => 0x02\n" *
            "  0x03 => 0x04"
    else
        @test occursin("FlatDict", showstr(fd))
        @test occursin("FlatDict", replstr(fd))
    end
end
