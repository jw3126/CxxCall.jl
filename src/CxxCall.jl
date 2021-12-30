module CxxCall
export @cxx
using CxxInterface
export cxxsetup, cxxnewfile

function parse_fdef(ex)
    if Meta.isexpr(ex, :function)
        @assert length(ex.args) == 2
        ann_call, body = ex.args
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
        f = popfirst!(args_ann)
        if Meta.isexpr(f, Symbol("."))
            @assert length(f.args) == 2
            lib, fun = f.args
        else
            msg = """
            Expected a calle of the form `lib.f`. Got:
            $f
            """
            throw(ArgumentError(msg))
        end
        args = map(args_ann) do arg_ann
            parse_type_annotation(arg_ann)
        end
        return (;lib, fun, args)
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
        @assert length(ex.args) == 2
        val, ann = ex.args
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

function make_cname(def)
    string(def.fun)
end

function eval_def(M::Module, def)
    fun = M.eval(def.fun)
    if !(fun isa Symbol)
        msg = """
        Function name must be a Symbol. Got:
        $(fun)
        """
        throw(ArgumentError(msg))
    end
    lib = M.eval(def.lib)
    if !(lib isa AbstractString)
        msg = """
        Library must be an AbstractString. Got:
        $lib
        """
        throw(ArgumentError(msg))
    end
    args = map(def.args) do arg
        val = arg.val
        if !(val isa Symbol)
            msg = """
            All arguments must be symbols. Got:
            $val
            """
            throw(ArgumentError(msg))
        end
        ann = M.eval(arg.ann)
        (;val, ann)
    end
    body = M.eval(def.body)
    if !(body isa AbstractString)
        msg = """
        Function body must be a String. Got:
        $body
        """
        throw(ArgumentError(msg))
    end
    return_type = M.eval(def.return_type)
    return (;lib, fun, args, return_type, body)
end

function cxxmacro(M::Module, ex)
    def = eval_def(M,parse_fdef(ex))
    cxxfunction(
        FnName(def.fun::Symbol, make_cname(def)::String, def.lib),
        FnResult(def.return_type, cxxname(cxxtype[def.return_type])),
        map(def.args) do arg
            CT = cxxname(cxxtype[arg.ann])
            FnArg(arg.val::Symbol, arg.ann, string(arg.val), CT, Any, identity)
        end,
        def.body::String,
    )
end

macro cxx(ex)
    esc(cxxmacro(__module__, ex))
end

# struct Arg
#     julia_type::Type
#     cxx_type::AbstractString
#     initial_julia_type::Type
#     convert_from_initial::Any
#     skip::Bool
# end
# 
# function CxxInterface.FnArg(name::Symbol, arg::Arg)
#     FnArg(arg.julia_name, 
#           arg.julia_type, 
#           string(name), 
#           arg.cxxtype,
#           arg.initial_julia_type,
#           arg.convert_from_initial,
#           arg.skip,
#     )
# end

end
