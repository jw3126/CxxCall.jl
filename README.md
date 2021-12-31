# CxxCall

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jw3126.github.io/CxxCall.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jw3126.github.io/CxxCall.jl/dev)
[![Build Status](https://github.com/jw3126/CxxCall.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jw3126/CxxCall.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jw3126/CxxCall.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jw3126/CxxCall.jl)

[CxxCall](https://github.com/jw3126/CxxCall.jl) allows calling C++ code from Julia:
```julia
using CxxCall
...
@cxx mylib function add(x::Cint, y::Cint)::Cfloat
    """
    float ret = x + y;
    std::cout << "Welcome to libAddCxx" << std::endl;
    std::cout << "x=" << x << " y=" << y << " ret=" << ret << std::endl;
    return ret;
    """
end
...
```
For complete examples check out the tests.

# Acknowledgements
* [CxxCall.jl](https://github.com/jw3126/CxxCall.jl) is just syntactic sugar on top of 
[CxxInterface.jl](https://github.com/eschnett/CxxInterface.jl). The actual work is done by CxxInterface.jl.

# Alternatives

* [Cxx.jl](https://github.com/JuliaInterop/Cxx.jl) allows to mix julia and C++ code. It is an amazing proof of concept, but notoriously hard to maintain.
* [CxxWrap.jl](https://github.com/JuliaInterop/CxxWrap.jl) is probably the most mature option.
The user specifies the wrapping on the C++ side.
* [CxxInterface.jl](https://github.com/eschnett/CxxInterface.jl).
Wrappers are specified on the julia side using string manipulation. Compared to the above alternatives, this approach is very simple.
* `Base.ccall`. Writing a C-API and calling it manually using `ccall` is always an option. If templates are involved the amount of code becomes unwieldy quickly however.
