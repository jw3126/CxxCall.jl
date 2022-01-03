module CxxCall
export @cxx
using CxxInterface
export cxxsetup, cxxnewfile
export tocxx

# compat

if !isdefined(Base, :Returns)
    function Returns(x)
        function returns(args...; kw...)
            x
        end
    end
end

# parser

function parse_fdef(ex)
    if Meta.isexpr(ex, :where)
        msg = """
        Function definitions with where clause are not supported.
        """
        throw(ArgumentError(msg))
    elseif Meta.isexpr(ex, :function) || Meta.isexpr(ex, Symbol("="))
        @assert length(ex.args) == 2
        ann_call, body = ex.args
        check_body(body)
        (;parse_call_with_rettype(ann_call)..., body)
    else
        msg = """
        Expected a long form function definition. Got:
        $(ex)
        """
        throw(ArgumentError(msg))
    end
end

function parse_call(ex)
    if Meta.isexpr(ex, :call)
        @assert length(ex.args) >= 1
        args_ann = copy(ex.args)
        fun = popfirst!(args_ann)
        args = map(args_ann) do arg_ann
            parse_type_annotation(arg_ann)
        end
        return (;fun, args)
    else
        msg = """
        Expected function call. Got:
        $ex
        """
        throw(ArgumentError(msg))
    end
end

function parse_type_annotation(ex)
    # t :: T
    if Meta.isexpr(ex, Symbol("::"))
        if length(ex.args) == 1
            val = nothing
            ann = only(ex.args)
        else
            @assert length(ex.args) == 2
            val, ann = ex.args
        end
        return (;val, ann)
    else
        msg = """
        Expected type annotation. Got:
        $(ex)
        """
        throw(ArgumentError(msg))
    end
end

function parse_call_with_rettype(ex)
    # f(x::X) :: Ret
    if Meta.isexpr(ex, Symbol("::"))
        call, return_type = parse_type_annotation(ex)
        return (;parse_call(call)..., return_type=return_type)
    else
        msg = """
        Expected return type annotation. Got:
        $(ex)
        """
        throw(ArgumentError(msg))
    end
end

const SALT = "tR8P"
function make_cname(fun, res::FnResult, args::Vector{FnArg})
    io = IOBuffer()
    print(io, cxxname(string(fun)))
    print(io, "_")
    print(io, SALT)
    print(io, "_")
    print(io, cxxname(res.cxx_type))
    for arg in args
        print(io, "_")
        print(io, cxxname(arg.cxx_type))
    end
    seekstart(io)
    read(io, String)
end

function make_cxxfunction(fun, lib, return_type, args, anns, body)
    fres = FnResult(return_type, tocxx(return_type))
    fargs = map(args, anns) do arg, ann
        FnArg(arg, ArgAnn(ann))
    end
    cxx_fun_name = make_cname(fun, fres, fargs)
    fname = FnName(fun, cxx_fun_name, lib)
    cxxfunction(fname, fres, fargs, body)
end

function check_body(ex)
    @nospecialize
    if Meta.isexpr(ex, :return)
        error("""
              Body of @cxx function should not contain return statement. Found
              $ex
              """)
    elseif ex isa Expr
        for arg in ex.args
            check_body(arg)
        end
    end
end

function cxxexprmacro(lib, ex)
    def = parse_fdef(ex)
    fun = if Meta.isexpr(def.fun, :curly)
        error("Function names with curly brackets Foo{T} are currently not supported.")
        # the problem is that these usually are Type{...} but CxxInterface only supports
        # Union{Symbol, Expr}
        Expr(:block, def.fun)
    else
        QuoteNode(def.fun)
    end
    return_type = def.return_type

    args = Expr(:ref, :Symbol,
        map(eachindex(def.args), def.args) do i, arg
            if arg.val === nothing
                QuoteNode(Symbol("_", SALT, "_", i))
            else
                QuoteNode(arg.val)
            end
        end...
    )
    anns = Expr(:vect,
        map(arg->arg.ann, def.args)...
    )
    @assert Meta.isexpr(def.body, :block)
    # wrap body in let expr so assignments don't leak into outer scope
    body = Expr(:let, Expr(:block,),def.body)
    ret = Expr(:call, make_cxxfunction,
         fun, lib, return_type, args, anns, body
    )
    ret
end

function cxxmacro(lib, ex)
    Expr(:call, :eval, cxxexprmacro(lib, ex))
end

macro cxx(lib, ex)
    esc(cxxmacro(lib, ex))
end

struct ArgAnn
    julia_type::Type
    cxx_type::AbstractString
    initial_julia_type::Type
    convert_from_initial::Any
    skip::Bool
end
ArgAnn(o::ArgAnn) = o

function CxxInterface.FnArg(julia_name::Symbol, arg::ArgAnn)
    cxx_name = string(julia_name)
    FnArg(julia_name, 
          arg.julia_type, 
          cxx_name,
          arg.cxx_type,
          arg.initial_julia_type,
          arg.convert_from_initial,
          ;arg.skip,
    )
end

"""
    tocxx(::Type{MyJuliaType})::String

Return the corresponding C++ type as a string from the julia type.
```jldoctest
julia> using CxxCall: tocxx

julia> tocxx(Float64)
"double"

julia> tocxx(Int8)
"int8_t"
```
"""
function tocxx end


export Convert
struct Convert{From,To} end
function (o::Convert{From,To})(expr) where {From,To}
    :(convert($To,$expr::$From))
end
function from_to(::Convert{From,To}) where {From, To}
    From, To
end
function Convert(from_to::Pair)
    From, To = from_to
    Convert{From, To}()
end

function ArgAnn(convert_from_initial::Convert)
    initial_julia_type, julia_type = from_to(convert_from_initial)
    cxx_type = tocxx(julia_type)
    convert_from_initial = Convert{initial_julia_type, julia_type}()
    ArgAnn(julia_type,
        cxx_type,
        initial_julia_type,
        convert_from_initial,
        false
    )
end

function ArgAnn(julia_type::Type{Type{T}}) where {T}
    cxx_type = "void*"
    ArgAnn(Ptr{Cvoid},
        cxx_type,
        julia_type,
        Returns(:(C_NULL)),
        false
    )
end

function ArgAnn(julia_type::Type)
    cxx_type = tocxx(julia_type)
    initial_julia_type = julia_type
    ArgAnn(julia_type,
        cxx_type,
        initial_julia_type,
        identity,
        false
    )
end

function arg_ann_cstring(julia_type)
    cxx_type = tocxx(julia_type)
    initial_julia_type = AbstractString
    ArgAnn(julia_type,
           cxx_type,
           initial_julia_type,
           identity,
           false
    )
end

ArgAnn(julia_type::Type{Cstring}) = arg_ann_cstring(Cstring)
ArgAnn(julia_type::Type{Cwstring}) = arg_ann_cstring(Cwstring)

function tocxx(::Type{Ptr{T}}) where {T}
    tocxx(T) * "*"
end

function destar(str::AbstractString)
    s = rstrip(str)
    if isempty(s)
        throw(ArgumentError("Nonempty string expected"))
    elseif s[end] === '*'
        rstrip(s[begin:end-1])
    else
        throw(ArgumentError("Expected last character to be '*', got:\n$s"))
    end
end

# TODO remove patch when CxxInterface has these
const cxxtype_patched = merge(cxxtype,
    Dict(
        Cvoid    => "void",
        Cstring  => "char*",
        Cwstring => "wchar*",
    )
)

for (julia_type, cxx_type) in pairs(cxxtype_patched)
    @eval tocxx(::Type{$julia_type})::String = $cxx_type
end

end
