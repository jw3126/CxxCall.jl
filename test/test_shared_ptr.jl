module TestSharedPtr
module Wrapper
    using CxxCall
    using CxxCall: destar
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
        std::cout << "construct S(" << value << ")" << std::endl;
        }
        ~S() {
            deaths += 1;
            std::cout << "delete S(" << value << ")" << "(" << deaths << " deaths)" << std::endl;
        }
    };

    struct ShareHolder {
        std::shared_ptr<S> s;
        ShareHolder(std::shared_ptr<S> s_) : s(s_) {};
    };
    """))

    struct S end
    CxxCall.cxxtypename(::Type{S}) = "S"
    @cxx lib function cxxnew(::Type{S}, value::Cint)::Ptr{S}
        """
        S* ret = new S(value);
        return ret;
        """
    end
    @cxx lib free(self::Ptr{S})::Cvoid = "delete self;"

    struct SharedPtr{T} end
    function CxxCall.cxxtypename(::Type{SharedPtr{T}}) where {T}
        "std::shared_ptr<$(cxxtypename(T))>"
    end
    for T in [S]
        @cxx lib function cxxnew(::Type{SharedPtr{T}}, obj::Ptr{T})::Ptr{SharedPtr{T}}
            """
            $(cxxtypename(SharedPtr{T}))* ret = new $(cxxtypename(SharedPtr{T}))(nullptr);
            ret->reset(obj);
            return ret;
            """
        end
        @cxx lib free(self::Ptr{SharedPtr{T}})::Cvoid = "delete self;"
        @cxx lib use_count(self::Ptr{SharedPtr{T}})::Clong = "return self->use_count();"
    end

    struct ShareHolder end
    CxxCall.cxxtypename(::Type{ShareHolder}) = "ShareHolder"
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


    #     @cxx lib function new_SharedPtr(::Type{T})::SharedPtr{T}
    #         """
    #         return new $(destar(cxxtypename(SharedPtr{T}))) (nullptr);
    #         """
    #     end
    #     @cxx lib function reset(self::SharedPtr{T}, t::T)::Cvoid
    #         """
    #         self->reset(t);
    #         """
    #     end

    #     ptr::Ptr{SharedPtr{T}}
    # end
    # function SharedPtr{T}(t::T) where {T}
    #     ret = new_SharedPtr(T);
    #     reset(ret, t)
    # end
    # function CxxCall.cxxtypename(::Type{SharedPtr{T}}) where {T}
    #     "std::shared_ptr<$(destar(cxxtypename(T)))>*"
    # end
    # for T in [S]
    #     @cxx lib function new_SharedPtr(::Type{T})::SharedPtr{T}
    #         """
    #         return new $(destar(cxxtypename(SharedPtr{T}))) (nullptr);
    #         """
    #     end
    #     @cxx lib function reset(self::SharedPtr{T}, t::T)::Cvoid
    #         """
    #         self->reset(t);
    #         """
    #     end
    #     @cxx lib function free(self::SharedPtr{T})::Cvoid
    #         """
    #         delete self;
    #         """
    #     end
    # end

end#module Wrapper

using Test
import .Wrapper; const W = Wrapper
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
end#module
