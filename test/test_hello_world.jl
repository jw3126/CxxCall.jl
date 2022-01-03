module TestAdd

module Wrapper
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
end#module Wrapper

using Test
import .Wrapper

@test !ispath(Wrapper.filepath)
Wrapper.cxx_write_code!()
@test isfile(Wrapper.filepath)
libpath = Wrapper.lib * ".so"
run(`g++ -shared -fPIC $(Wrapper.filepath) -o $libpath`)
@test isfile(libpath)
using Libdl
dlopen(libpath)
Wrapper.hello("world")

end#module
