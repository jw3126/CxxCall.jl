module TestAdd

using CxxCall
dir = mktempdir()
lib = joinpath(dir, "libHelloWorld")
filepath = joinpath(dir, "HelloWorld.cxx")
eval(cxxsetup())
eval(cxxnewfile(filepath,
"""
#include <iostream>
"""))

@cxx lib function hello(name::Cstring)::Cvoid
    """
    std::cout << "Hello " << name << "!" << std::endl;
    """
end

using Test
using Libdl

@testset "hello_world" begin
    @test !ispath(filepath)
    cxx_write_code!()
    @test isfile(filepath)
    libpath = "$(lib).$dlext"
    run(`g++ -shared -fPIC $(filepath) -o $libpath`)
    @test isfile(libpath)
    dlopen(libpath)
    hello("world")
end

end#module
