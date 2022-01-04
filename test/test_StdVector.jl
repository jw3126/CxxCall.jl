module TestStdVector

module Wrapper
    using CxxCall
    dir = mktempdir()
    lib = joinpath(dir, "libStdVector")
    filepath = joinpath(dir, "StdVector.cxx")
    eval(cxxsetup())
    eval(cxxnewfile(filepath,
    """
    #include <vector>
    """))

    struct StdVectorTag{T} end
    CxxCall.tocxx(::Type{StdVectorTag{T}}) where {T} = "std::vector<$(tocxx(T))>"

    mutable struct StdVector{T} <: AbstractVector{T}
        ptr::Ptr{StdVectorTag{T}}
        function StdVector{T}() where {T}
            ptr = cxxnew(StdVectorTag{T})
            ret = new{T}(ptr)
            finalizer(ret) do self
                free(self.ptr)
            end
            return ret
        end
    end
    function Base.size(o::StdVector) 
        GC.@preserve o begin
            (Int(len(o.ptr)),)
        end
    end
    function Base.getindex(o::StdVector, i::Integer)
        @boundscheck checkbounds(o,i)
        GC.@preserve o begin
            at(o.ptr, Csize_t(i-1))
        end
    end
    function Base.push!(o::StdVector, val)
        valT = convert(eltype(o), val)
        GC.@preserve o begin
            push_back(o.ptr, valT)
        end
        valT
    end

    for T in (Float32,Float64,Bool)
        Self = Ptr{StdVectorTag{T}}
        @cxx lib function cxxnew(::Type{StdVectorTag{T}})::Ptr{StdVectorTag{T}}
            """
            return new std::vector<$(tocxx(T))>();
            """
        end
        @cxx lib function free(self::Self)::Nothing
            "delete self;"
        end
        @cxx lib function at(self::Self, i::Csize_t)::T
            "return self->at(i);"
        end
        @cxx lib function push_back(self::Self, val::T)::Nothing
            "self->push_back(val);"
        end
        @cxx lib function len(self::Self)::Int64
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
    
    v = W.StdVector{Float64}()
    push!(v, 10.0)
    push!(v, 20.0)
    push!(v, 30.0)
    @test collect(v) == [10.0, 20.0, 30.0]
    @test size(v) == (3,)
    @test eltype(v) == Float64
end

end#module
