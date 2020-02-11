@testset "MultiDict construction ($A, $B)" for (A, B) in gettypes()
    md = MultiDict{A,B}()
    @test md isa MultiDict{A,B}
    @test isempty(md)
    @test length(md) == 0
end
