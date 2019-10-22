@testset "construction ($A, $B)" for (A, B) in gettypes()
    @test FlatDict{A,B}() isa FlatDict{A,B}
end

@testset "update ($A, $B)" for (A, B) in gettypes()
    fd = FlatDict{A,B}()
    a, b, c = _rand.((A, B, B))

    # setindex!
    res = fd[a] = b
    @test res === b

    if B !== Missing
        @test (a => b) in fd
        @test fd[a] === b
    else
        @test missing === ((a => b) in fd)
        @test fd[a] === b === missing
    end

    if A <: Number
        x = A(0)
        @assert isequal(x, 0)
        fd[0] = b
        @test isequal(fd[0], b)
        @test isequal(fd[x], b)
        fd[x] = c
        @test isequal(fd[0], c)
        @test isequal(fd[x], c)

        delete!(fd, 0)
        @test 0 ∉ keys(fd)
        if !isequal(0, a)
            @test !isempty(fd)
        else
            @test isempty(fd)
        end
    end
    if B <: Number
        y = B(0)
        @assert isequal(y, 0)
        fd[a] = 0
        @test isequal(fd[a], 0)
        @test isequal(fd[a], y)
        fd[a] = y
        @test isequal(fd[a], 0)
        @test isequal(fd[a], y)
    end
    i = Int64(2)^60+1
    if A <: Base.IEEEFloat
        k = A(i)
        @assert k != i
        @assert k isa A
        fd[k] = b
        @test isequal(fd[k], b)
        @test_throws KeyError fd[i]
        @test_throws ArgumentError fd[i] = b

        @test_throws ArgumentError delete!(fd, i)
        delete!(fd, k)
        @test k ∉ keys(fd)
        if !isequal(k, a)
            @test !isempty(fd)
        end
    end
    if B <: Base.IEEEFloat
        k = B(i)
        @assert k != i
        @assert k isa B
        fd[a] = i
        @test fd[a] === k
        fd[a] = k
        @test fd[a] === k
    end

    # push!(fd, pairs...)
    @test push!(fd, a => b) === fd
    @test push!(fd, a => b, a => c) === fd

    elts = [_rand(A) => _rand(B) for _=1:rand(1:9)]

    @test push!(fd, elts...) === fd

    seen = Set{A}()
    for (k, v) in reverse(elts)
        k in seen && continue
        push!(seen, k)
        if B !== Missing
            @test (k => v) in fd
            @test fd[k] === v
        else
            @test missing === ((k => v) in fd)
            @test fd[k] === v === missing
        end
    end

    # empty!
    @test !isempty(fd)
    @test fd === delete!(fd, a)
    @test a ∉ keys(fd)
    empty!(fd)
    @test isempty(fd)

    # pop!(fd)
    push!(fd, elts...)
    empty!(seen)
    # can't use rev=true, as this doesn't reverse equal elements, by sort-stability
    for (k, v) in reverse!(sort(elts, by=first))
        k in seen && continue
        push!(seen, k)
        @test pop!(fd) === (k => v)
    end
    @test isempty(fd)

    # pop!(fd, key)
    push!(fd, elts...)
    empty!(seen)

    # TODO: use something like shuffle!(unique!(reverse!(sort(...)), by=first))
    for (k, v) in reverse!(sort(elts, by=first))
        k in seen && continue
        push!(seen, k)
        @test pop!(fd, k) === v
        @test_throws KeyError pop!(fd, k)
    end
    @test isempty(fd)
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
            @test get(fd, c, nothing) === nothing
            @test get(fd, c, missing) === missing
            @test get(fd, c, Some(:def)) === Some(:def)

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
