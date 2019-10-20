const TYPES = (Nothing, Missing, Int32, Int64, BigInt, Float32, Float64, BigFloat, String, Symbol)

@testset "construction" begin
    A, B = rand(TYPES, 2)
    @test FlatDict{A,B}() isa FlatDict{A,B}
end
