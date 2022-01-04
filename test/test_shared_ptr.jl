module TestSharedPtr
module Wrapper
    using CxxCall
    dir = mktempdir()
    lib = joinpath(dir, "libSharedPtr")
    filepath = joinpath(dir, "SharedPtrCxx.cxx")
    eval(cxxsetup())
    eval(cxxnewfile(filepath,
    """
    #include <memory>
    #include <iostream>
    struct S {
        int value;
        int deaths;
        S(int x) : value(x), deaths(0){
        }
        ~S() {
            deaths += 1;
        }
    };

    struct ShareHolder {
        std::shared_ptr<S> s;
        ShareHolder(std::shared_ptr<S> s_) : s(s_) {};
    };
    """))

    struct S end
    CxxCall.tocxx(::Type{S}) = "S"
    @cxx lib function cxxnew(::Type{S}, value::Cint)::Ptr{S}
        """
        S* ret = new S(value);
        return ret;
        """
    end
    @cxx lib free(self::Ptr{S})::Cvoid = "delete self;"

    struct SharedPtr{T} end
    function CxxCall.tocxx(::Type{SharedPtr{T}}) where {T}
        "std::shared_ptr<$(tocxx(T))>"
    end
    for T in [S]
        @cxx lib function cxxnew(::Type{SharedPtr{T}}, obj::Ptr{T})::Ptr{SharedPtr{T}}
            """
            $(tocxx(SharedPtr{T}))* ret = new $(tocxx(SharedPtr{T}))(nullptr);
            ret->reset(obj);
            return ret;
            """
        end
        @cxx lib free(self::Ptr{SharedPtr{T}})::Cvoid = "delete self;"
        @cxx lib use_count(self::Ptr{SharedPtr{T}})::Clong = "return self->use_count();"
    end

    struct ShareHolder end
    CxxCall.tocxx(::Type{ShareHolder}) = "ShareHolder"
    @cxx lib function free(self::Ptr{ShareHolder})::Cvoid
        "delete self;"
    end
    @cxx lib function cxxnew(::Type{ShareHolder}, ps::Ptr{SharedPtr{S}})::Ptr{ShareHolder}
        "return new ShareHolder(*ps);"
    end
    @cxx lib function get_deaths(self::Ptr{ShareHolder})::Cint
        "return self->s.get()->deaths;"
    end
    @cxx lib function get_deaths(self::Ptr{SharedPtr{S}})::Cint
        "return self->get()->deaths;"
    end
    @cxx lib function get_value(self::Ptr{ShareHolder})::Cint
        "return self->s.get()->value;"
    end
    @cxx lib function use_count(self::Ptr{ShareHolder})::Clong
        "return self->s.use_count();"
    end
end#module Wrapper

using Test
import .Wrapper; const W = Wrapper
@testset "shared_ptr" begin
    @test !ispath(W.filepath)
    W.cxx_write_code!()
    @test isfile(W.filepath)
    libpath = W.lib * ".so"
    run(`g++ -shared -fPIC $(Wrapper.filepath) -o $libpath`)
    s = W.cxxnew(W.S, Cint(1))
    sp = W.cxxnew(W.SharedPtr{W.S}, s)
    @test W.use_count(sp) == 1
    holder = W.cxxnew(W.ShareHolder, sp)
    @test W.use_count(sp) == 2
    @test W.use_count(holder) == 2
    @test W.get_deaths(holder) == 0
    @test W.get_deaths(sp)     == 0
    holder2 = W.cxxnew(W.ShareHolder, sp)
    @test W.use_count(sp) == 3
    @test W.use_count(holder) == 3
    @test W.use_count(holder2) == 3
    W.free(sp)
    @test W.get_deaths(holder) == 0
    @test W.get_deaths(holder2) == 0
    @test W.use_count(holder) == 2
    @test W.use_count(holder2) == 2
    W.free(holder)
    @test W.use_count(holder2) == 1
    @test W.get_deaths(holder2) == 0
    W.free(holder2)
end
end#module
