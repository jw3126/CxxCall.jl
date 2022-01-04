module CxxCall

#@nospecialize

export @cxx
export @cxxexpr
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
        Expected a function definition. Got:
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

const SALT = "tR8l"
function make_cname(fun, res::FnResult, args::Vector{FnArg})
    # TODO 
    # This is hacky. Some problems are:
    # * function names can get very long. We could use a hash to shorten them.
    # * distinct initial_julia_type can give the same C++ type, which gives name clashes
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
    fres = FnResult(RetAnn(return_type))
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
    elseif Meta.isexpr(def.fun, Symbol("\$"))
        only(def.fun.args)
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

macro cxxexpr(lib, ex)
    esc(cxxexprmacro(lib, ex))
end

"""
    ArgAnn

ArgAnn is short for "argument annotation". 
It is used for customizing `@cxx` function argument handling.
"""
struct ArgAnn
    julia_type::Type
    cxx_type::AbstractString
    initial_julia_type::Type
    convert_from_initial::Any
    skip::Bool
end
ArgAnn(o::ArgAnn) = o
function ArgAnn(;
    julia_type::Type,
    cxx_type::AbstractString=tocxx(julia_type),
    initial_julia_type::Type=julia_type,
    convert_from_initial::Any=identity,
    skip::Bool=false,
    )
    ArgAnn(
        julia_type,
        cxx_type,
        initial_julia_type,
        convert_from_initial,
        skip::Bool
    )
end
function Base.show(io::IO, o::ArgAnn)
    print(io, ArgAnn)
    println(io,"(")
    println(io, "  julia_type           =  ", o.julia_type, ",")
    println(io, "  cxx_type             =  ", o.cxxtype, ",")
    println(io, "  initial_julia_type   =  ", o.initial_julia_type, ",")
    println(io, "  convert_from_initial =  ", o.convert_from_initial, ",")
    print(io, "  skip                 =  ", o.skip, ")")
end

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
    RetAnn

RetAnn is short for "return annotation". 
It is used for customizing `@cxx` return value handling.
"""
struct RetAnn
    julia_type::Type
    cxx_type::AbstractString
    final_julia_type::Type
    convert_to_final::Any
end
function CxxInterface.FnResult(o::RetAnn)
    FnResult(o.julia_type, o.cxx_type, o.final_julia_type, o.convert_to_final)
end
RetAnn(o::RetAnn) = o
RetAnn(T::Type) = RetAnn(julia_type=T)
function RetAnn(;
    julia_type::Type,
    cxx_type::AbstractString=tocxx(julia_type),
    final_julia_type::Type=julia_type,
    convert_to_final::Any=identity,
    )
    RetAnn(
        julia_type,
        cxx_type,
        final_julia_type,
        convert_to_final,
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
struct Convert
    FromTo::Pair{Type,Type}
end
function (o::Convert)(expr)
    From, To = o.FromTo
    :(convert($To,$expr::$From))
end

function ArgAnn(convert_from_initial::Convert)
    initial_julia_type, julia_type = convert_from_initial.FromTo
    cxx_type = tocxx(julia_type)
    convert_from_initial = Convert(initial_julia_type=>julia_type)
    ArgAnn(;julia_type,
        cxx_type,
        initial_julia_type,
        convert_from_initial,
    )
end

function ArgAnn(initial_julia_type::Type{Type{T}}) where {T}
    ArgAnn(;julia_type=Ptr{Cvoid},
        cxx_type="void*",
        initial_julia_type=Type{T},
        convert_from_initial=Returns(:(C_NULL)),
    )
end

function ArgAnn(initial_julia_type::Type)
    ArgAnn(;julia_type=initial_julia_type,
        cxx_type=tocxx(initial_julia_type),
        initial_julia_type,
    )
end

function arg_ann_cstring(julia_type)
    cxx_type = tocxx(julia_type)
    initial_julia_type = Union{AbstractString, julia_type}
    ArgAnn(;julia_type,
           cxx_type,
           initial_julia_type,
    )
end

ArgAnn(julia_type::Type{Cstring}) = arg_ann_cstring(Cstring)
ArgAnn(julia_type::Type{Cwstring}) = arg_ann_cstring(Cwstring)

function tocxx(::Type{Ptr{T}}) where {T}
    # TODO
    # certainly this works for simple cases
    # but is it always correct?
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
        Cwstring => "wchar_t*",
    )
)

for (julia_type, cxx_type) in pairs(cxxtype_patched)
    @eval tocxx(::Type{$julia_type})::String = $cxx_type
end

end
