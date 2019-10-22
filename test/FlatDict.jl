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
    int = Int64(2)^60+1
    if A <: Union{Base.IEEEFloat,Base.BitInteger32}
        k = A <: AbstractFloat ? A(int) : typemax(A)
        @assert k != int
        @assert k isa A
        fd[k] = b
        @test isequal(fd[k], b)

        Err = A <: AbstractFloat ? ArgumentError : InexactError
        @test_throws Err fd[int]
        @test_throws Err fd[int] = b
        @test_throws Err get(fd, int, :def)
        @test_throws Err get(() -> :def, fd, int)
        @test_throws Err pop!(fd, int)
        @test_throws Err pop!(fd, int, :def)
        @test_throws Err delete!(fd, int)

        delete!(fd, k)
        @test k ∉ keys(fd)
        if !isequal(k, a)
            @test !isempty(fd)
        end
    end
    if B <: Base.IEEEFloat
        k = B(int)
        @assert k != int
        @assert k isa B
        fd[a] = int
        @test fd[a] === k
        fd[a] = k
        @test fd[a] === k
    end

    # push!(fd, pairs...)
    @test push!(fd, a => b) === fd
    @test push!(fd, a => b, a => c) === fd

    # using MAX_NEWS_SEARCH, in the hope that in some cases, the dictionary
    # will be `resort!`ed, but not always, in order to test different code paths
    elts = [_rand(A) => _rand(B) for _=1:rand(1:MAX_NEWS_SEARCH+8)]

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

    for (k, v) in shuffle!(unique!(first, reverse(elts)))
        k in seen && continue
        push!(seen, k)
        @test pop!(fd, k) === v
        @test_throws KeyError pop!(fd, k)
    end
    @test isempty(fd)

    # pop!(fd, key, default)
    push!(fd, elts...)
    empty!(seen)

    local e
    for (k, v) in shuffle!(unique!(first, reverse(elts)))
        k in seen && continue
        push!(seen, k)
        if !Base.issingletontype(A) && A !== Bool
            while true
                e = _rand(A)
                e ∉ keys(fd) && break
            end
            @test pop!(fd, e, :def) === :def
            @test pop!(fd, e, Some(:def)) === Some(:def)
            @test pop!(fd, e, nothing) === nothing
            @test pop!(fd, e, Some(nothing)) === Some(nothing)
        end
        @test pop!(fd, k, :def) === v
    end
    @test isempty(fd)

    # get!(fd, key, default) / get!(fun, fd, key)
    ref = Ref(false)
    fun(val) = function ()
        ref[] = true
        val
    end

    get!(fd, a, b) === b
    @test fd[a] === b
    @test length(fd) == 1
    get!(fd, a, b) === b
    @test fd[a] === b
    @test length(fd) == 1

    empty!(fd)
    get!(fun(b), fd, a) === b
    @test ref[]
    @test fd[a] === b
    @test length(fd) == 1
    ref[] = false
    get!(fun(b), fd, a) === b
    @test !ref[]
    @test fd[a] === b
    @test length(fd) == 1

    @test get!(fd, a, :def) === b
    @test fd[a] === b

    @test get!(fun(:def), fd, a) === b
    @test !ref[]
    @test fd[a] === b

    @test get!(fd, a, _rand(B)) === b
    @test fd[a] === b

    @test get!(fun(_rand(B)),  fd, a) === b
    @test !ref[]
    @test fd[a] === b

    if !Base.issingletontype(A) && A !== Bool
        while true
            e = _rand(A)
            e ∉ keys(fd) && break
        end
        if B !== Symbol
            @test_throws MethodError get!(fd, e, :def)
            @test_throws MethodError get!(fun(:def), fd, e)
            @test ref[]
            ref[] = false
        end
        if B <: Base.BitInteger32
            @test_throws InexactError get!(fd, e, int)
            @test_throws InexactError get!(fun(int), fd, e)
            @test ref[]
            ref[] = false
        end
        if B <: Number
            z = get!(fd, e, 0x0)
            @test iszero(z)
            @test z isa B
            @test pop!(fd, e) === z
            if B !== Bool
                x = rand(1:typemax(Int8))
                z = get!(fd, e, x)
                @test z == x
                @test z isa B
                @test pop!(fd, e) === z
            end

            @test !haskey(fd, e)
            z = get!(fun(0x0), fd, e)
            @test ref[]
            ref[] = false
            @test iszero(z)
            @test z isa B
            @test pop!(fd, e) === z
            if B !== Bool
                x = rand(1:typemax(Int8))
                z = get!(fun(x), fd, e)
                @test ref[]
                ref[] = false
                @test z == x
                @test z isa B
                @test pop!(fd, e) === z
            end
        end
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

    ref = Ref(false)
    fun() = (ref[] = true; :def)

    @test get(fun, fd, a) === b
    @test ref[] == false

    if !Base.issingletontype(A)
        while true
            c = _rand(A)
            isequal(a, c) && continue

            @test get(fd, c, :def) === :def
            @test get(fd, c, nothing) === nothing
            @test get(fd, c, missing) === missing
            @test get(fd, c, Some(:def)) === Some(:def)

            g = get(fun, fd, c)
            @test g === :def
            @test ref[] == true
            ref[] = false

            @test_throws KeyError fd[c]

            fd[c] = b
            @test get(fd, c, :def) === b
            @test length(fd) == 2
            @test get(fd, c, :def) === b

            @test get(fun, fd, c) === b
            @test ref[] == false

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
