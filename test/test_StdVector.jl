module TestStdVector

module Wrapper
    using CxxCall
    dir = mktempdir()
    lib = joinpath(dir, "libStdVectorCxx")
    filepath = joinpath(dir, "StdVectorCxx.cxx")
    eval(cxxsetup())
    eval(cxxnewfile(filepath,
    """
    #include <vector>
    """))

    struct StdVector{T} <: AbstractVector{T}
        ptr::Ptr{StdVector{T}}
    end
    CxxCall.tocxx(::Type{StdVector{T}}) where {T} = "std::vector<$(tocxx(T))>*"
    # CxxCall.ArgAnn(::Type{StdVector{T}}) where {T} = ArgAnn()
    Base.size(o::StdVector) = (length(o),)
    function Base.getindex(o::StdVector, i::Integer)
        @boundscheck checkbounds(o,i)
        at(o, Csize_t(i-1))
    end
    function destar(x::AbstractString)
        @assert x[end] == '*'
        x[begin:end-1]
    end

    for T in (Float32,Float64,Bool)
        vectorT = tocxx(StdVector{T})
        StdVector{T}() = new_StdVector(T)
        @cxx lib function new_StdVector(::Type{T})::StdVector{T}
            """
            return new $(destar(vectorT))();
            """
        end
        @cxx lib function free(self::StdVector{T})::Nothing
            "delete self;"
        end
        @cxx lib function at(self::StdVector{T}, i::Csize_t)::T
            "return self->at(i);"
        end
        @cxx lib function Base.push!(self::StdVector{T}, val::T)::Nothing
            "self->push_back(val);"
        end
        @cxx lib function Base.length(self::StdVector{T})::Int64
            "return self->size();"
        end
    end
end#module Wrapper

using Test
import .Wrapper; const W = Wrapper

@testset "StdVector" begin
    @test !ispath(W.filepath)
    W.cxx_write_code!()
    @test isfile(W.filepath)
    libpath = W.lib * ".so"
    run(`g++ -shared -fPIC $(Wrapper.filepath) -o $libpath`)
    @test isfile(libpath)
    using Libdl
    dlopen(libpath)
    v = W.StdVector{Float32}()
    push!(v, 10f0)
    push!(v, 20f0)
    push!(v, 30f0)
    @test v[1] === 10f0
    @test v[2] === 20f0
    @test v[3] === 30f0
    W.free(v)
    
    v = W.StdVector{Float64}()
    push!(v, 10.0)
    push!(v, 20.0)
    push!(v, 30.0)
    @test collect(v) == [10.0, 20.0, 30.0]
    @test size(v) == (3,)
    @test eltype(v) == Float64
    W.free(v)
end

end#module
