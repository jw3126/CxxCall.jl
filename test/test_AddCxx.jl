module TestAdd

module Wrapper
    using CxxCall
    dir = mktempdir()
    lib = joinpath(dir, "libAddCxx")
    filepath = joinpath(dir, "AddCxx.cxx")
    eval(cxxsetup())
    eval(cxxnewfile(filepath,
    """
    #include <iostream>
    """))
    
    @cxx lib function add(x::Cint, y::Cint)::Cfloat
        """
        float ret = x + y;
        std::cout << "Welcome to libAddCxx" << std::endl;
        std::cout << "x=" << x << " y=" << y << " ret=" << ret << std::endl;
        return ret;
        """
    end

    @cxx lib function add_sloppy(x::Convert(Any=>Cint), y::Convert(Int64=>Cint))::Cfloat
        """
        float ret = x + y;
        return ret;
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
@test Wrapper.add(Cint(1),Cint(2)) === 3f0
@test_throws MethodError Wrapper.add(Int64(1),Cint(2)) === 3f0
@test Wrapper.add_sloppy(Int128(1), Int64(2)) === 3f0
@test Wrapper.add_sloppy(Float16(1), Int64(2)) === 3f0
@test_throws MethodError Wrapper.add_sloppy(Float16(1), Int32(2)) === 3f0

end#module
