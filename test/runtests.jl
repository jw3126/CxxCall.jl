import CxxCall
using Test


@testset "parse_fdef" begin
    parse_fdef = CxxCall.parse_fdef
    ex1 = :(function M.f()::Res
          body
      end
     )
    
    def = parse_fdef(ex1)
    @test isempty(def.args)
    @test def.fun == :(M.f)
    @test def.return_type == :Res
    
    ex2 = :(function f(
            x::X,
            y::Y)::Z
                some 
                body
            end
    )
    parse_fdef(ex2)
    def = parse_fdef(ex2)
    @test def.fun == :f
    @test def.return_type == :Z
    @test def.args == [
     (val = :x, ann = :X),
     (val = :y, ann = :Y),
    ]
end

include("test_AddCxx.jl")
include("test_StdVector.jl")
