import CxxCall
using Test

include("test_hello_world.jl")
include("test_AddCxx.jl")
include("test_StdVector.jl")
include("test_shared_ptr.jl")

@testset "tocxx" begin
    for T in [
        Cstring,
        Cuchar,
        Cuint,
        Cchar,
        Cdouble,                   
        Cfloat,                  
        Cvoid,
        Cwchar_t,
        Cint,                  
        Cptrdiff_t,
        Clong,
        Clonglong,
        Cssize_t,
        Culong,
        Csize_t,    
        Cshort,    
        Cwstring,
        Culonglong,
        Cushort,
       ]
        @test CxxCall.tocxx(T) isa String
    end
end

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

    @test parse_fdef(:(f()::Y = y)) == 
        parse_fdef(:(function f()::Y y end))
    @test parse_fdef(:(f(x::X)::Y = y)) == 
        parse_fdef(:(function f(x::X)::Y y end))
    
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

    ex = :(function f(
            x::X,
            y::Y)::Z
                for i in 1:10
                    return i
                end
            end
    )
    @test_throws Exception parse_fdef(ex)

    ex = :(function f(
            y::Y)::Z where {Y}
            end
    )
    @test_throws Exception parse_fdef(ex)
end

