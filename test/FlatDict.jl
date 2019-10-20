@testset "construction" begin
    A, B = _randtypes()
    @test FlatDict{A,B}() isa FlatDict{A,B}
end

@testset "update" begin
    A, B = rand(TYPES, 2)
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

@testset "query" begin
    A, B = _randtypes()
    fd = FlatDict{A,B}()

    @test length(fd) == 0

    a, b = _rand.((A, B))
    fd[a] = b

    @test get(fd, a, :def) === b
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
