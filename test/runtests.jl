import CxxCall
using Test

module Test_tocxx
using Test
using CxxCall
@testset "tocxx" begin
    dir = mktempdir()
    lib = joinpath(dir, "libtest_tocxx")
    filepath = joinpath(dir, "test_tocxx.cxx")
    eval(cxxsetup())
    eval(cxxnewfile(filepath, ""))
    seen = Set(String[])
    types = [
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
    for T in types 
        @test CxxCall.tocxx(T) isa String
        Tcxx = tocxx(T)
        if !(Tcxx in seen)
            @cxx lib function id(obj::Ptr{T})::Ptr{T}
                "return obj;"
            end
            push!(seen, Tcxx)
        end
    end
    cxx_write_code!()
    @test isfile(filepath)
    libpath = "$(lib).so"
    run(`g++ -shared -fPIC $(filepath) -o $(libpath)`)
    using Libdl
    Libdl.dlopen(libpath) do _
        for T in types
            obj = Ptr{T}(C_NULL)
            @test id(obj) === obj
        end
    end
end
end#module test_tocxx

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

include("test_hello_world.jl")
include("test_AddCxx.jl")
include("test_StdVector.jl")
include("test_shared_ptr.jl")

