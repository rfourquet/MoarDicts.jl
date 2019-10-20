@testset "construction" begin
    A, B = rand(TYPES, 2)
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
    A, B = rand(TYPES, 2)
    fd = FlatDict{A,B}()
    a, b = _rand.((A, B))
    fd[a] = b

    @test get(fd, a, :def) === b

    if !Base.issingletontype(A)
        while true
            c = _rand(A)
            isequal(a, c) && continue
            @test get(fd, c, :def) === :def
            break
        end
    end
end
