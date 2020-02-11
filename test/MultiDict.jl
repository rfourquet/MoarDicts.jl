@testset "MultiDict construction ($A, $B)" for (A, B) in gettypes()
    md = MultiDict{A,B}()
    @test md isa MultiDict{A,B}
    @test isempty(md)
    @test length(md) == 0
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
    end
end
