module TestClassWithManyMethods

using CxxCall
using Test
using Libdl

dir = mktempdir()
lib = joinpath(dir, "libClassWithManyMethods")
filepath = joinpath(dir, "ClassWithManyMethods.cxx")
eval(cxxsetup())
eval(cxxnewfile(filepath,
"""
template <typename T>
struct ClassWithManyMethods {
    T number;
    T exact()      {return number+0;}
    T one_more()   {return number+1;}
    T two_more()   {return number+2;}
    T three_more() {return number+3;}
    T four_more()  {return number+4;}
    T five_more()  {return number+5;}
};
"""))
struct ClassWithManyMethods{T}
    _data::T
end
function CxxCall.tocxx(::Type{ClassWithManyMethods{T}}) where {T}
    "ClassWithManyMethods<$(tocxx(T))>"
end
for T in [Int, Float64]
    @cxx lib exact(self::ClassWithManyMethods{T})::T = "return self.exact();"
    # lets define the other methods in a loop
    for f in [
        :one_more,
        :two_more,
        :three_more,
        :four_more,
        :five_more,
        ]
        CT = ClassWithManyMethods{T}
        @cxx lib function $f(self::CT)::T
            """
            // lets check we are ABI compatible
            static_assert(sizeof($(tocxx(CT))) == $(sizeof(CT)));
            return self.$f();
            """
        end
    end
end

@testset "ClassWithManyMethods" begin
    @test !ispath(filepath)
    cxx_write_code!()
    @test isfile(filepath)
    libpath = lib * ".so"
    run(`g++ -shared -fPIC $filepath -o $libpath`)
    @test isfile(libpath)
    dlopen(libpath)
    
    obj = ClassWithManyMethods(42)
    @test exact(obj)      === 42+0
    @test one_more(obj)   === 42+1
    @test two_more(obj)   === 42+2
    @test three_more(obj) === 42+3
    @test four_more(obj)  === 42+4
    @test five_more(obj)  === 42+5

    obj = ClassWithManyMethods(42.0)
    @test exact(obj)      === 42.0+0
    @test one_more(obj)   === 42.0+1
    @test two_more(obj)   === 42.0+2
    @test three_more(obj) === 42.0+3
    @test four_more(obj)  === 42.0+4
    @test five_more(obj)  === 42.0+5
end

end#module
