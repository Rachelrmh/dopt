module dopt.core.ops;

import std.array;
import std.exception;
import std.variant;

import dopt.core.types;

public
{
    import dopt.core.ops.basic;
    import dopt.core.ops.math;
}

static this()
{
    dopt.core.ops.basic.initialize();
    dopt.core.ops.math.initialize();
}

alias Verifier = bool delegate(const Operation);
alias Judge = TensorType delegate(const(Operation));

/**
Contains methods to perform procedures specific to the type of an operation
*/
struct OpDef
{
    /**
    A verifier is used to ensure that an Operation object correctly constructed.
    */
    Verifier verifier;

    /**
    A judge produces a TensorType object that specifies the type of the result of an operation of this type.
    */
    Judge judge;
}

/**
A node in the expression graph
*/
class Operation
{
    public
    {
        /**
        Returns a string identifying the type of this operation. This is the same string used when registering the
        operation with the registerOperation method.
        */
        @property string opType() const
        {
            return mOpType;
        }

        /**
        Returns a TensorType object that specifies the type of tensor obtained by evaluating this operation.
        */
        @property const(TensorType) outputType() const
        {
            return mOutputType;
        }

        /**
        Returns a list of operands for this operation.
        */
        @property const(Operation)[] deps() const
        {
            return mDeps;
        }

        /**
        Returns an associative array that maps strings to operation specific attributes.
        */
        @property const(Variant[string]) attributes() const
        {
            return mAttributes;
        }

        /**
        Convenience method for pointwise operations.

        Internally, this just calls the appropriate function from dopt.core.ops.math.
        */
        Operation opBinary(string op)(const(Operation) rhs, string mod = __MODULE__, size_t line = __LINE__) const
        {
            static if(op == "+")
            {
                return this.add(rhs, mod, line);
            }
            else static if(op == "-")
            {
                return this.sub(rhs, mod, line);
            }
            else static if(op == "*")
            {
                return this.mul(rhs, mod, line);
            }
            else static if(op == "/")
            {
                return this.div(rhs, mod, line);
            }
            else
            {
                static assert(0, "Unknown binary operation '" ~ op ~ "'");
            }
        }

        Operation opBinary(string op)(int i, string mod = __MODULE__, size_t line = __LINE__) const
        {
            auto bc = int32([], [i])
                     .repeat(outputType.volume)
                     .reshape(outputType.shape);

            return opBinary!op(bc, mod, line);
        }

        Operation opBinary(string op)(float i, string mod = __MODULE__, size_t line = __LINE__) const
        {
            auto bc = float32([], [i])
                     .repeat(outputType.volume)
                     .reshape(outputType.shape);

            return opBinary!op(bc, mod, line);
        }

        Operation opUnary(string op)() const
        {
            static if(op == "-")
            {
                return neg(this);
            }
            else
            {
                static assert("Unknown unary operation '" ~ op ~ "'");
            }
        }

        override string toString() const
        {
            import std.algorithm : joiner, map;
            import std.conv : to;

            //If it's a variable, we should have some unique identifier
            if(opType == "variable")
            {
                //This is very ugly. Someone please come up with a better way.
                return to!string(cast(void *)this);
            }
            else
            {
                return opType ~ "(" ~ deps.map!(x => x.toString).joiner(", ").to!string ~ ")";
            }
        }
    }

    private
    {
        string mOpType;
        string mModule;
        size_t mLine;
        const(Operation)[] mDeps;
        const(Variant[string]) mAttributes;
        const(TensorType) mOutputType;

        this(string opType, const(Operation)[] deps, const(Variant[string]) attribs, string mod, size_t line)
        {
            import std.conv : to;
            
            mOpType = opType;
            mDeps = deps.array;
            mAttributes = attribs.dup;
            mModule = mod;
            mLine = line;

            enforce(mOpDefs[opType].verifier(this),
                "Operation failed verification. Instantiated at " ~ mod ~ ":" ~ line.to!string);

            mOutputType = makeJudgement(this);
        }
    }
}

/**
Registers an operation definition with the given identifier.
*/
void registerOperation(string name, OpDef def)
{
    enforce((name in mOpDefs) is null, "There is already an operation registered with the name '" ~ name ~ "'");

    mOpDefs[name] = def;
}

/**
Returns a list of identifiers for operations that have been registered so far.
*/
string[] listAllOperations()
{
    return mOpDefs.keys.dup;
}

/**
Creates an operation of the given type, with the given dependencies and attributes.
*/
Operation createOperation(string opType, const(Operation)[] deps = [], const(Variant[string]) attribs = null,
    string mod = __MODULE__, size_t line = __LINE__)
{
    import std.conv : to;

    enforce(opType in mOpDefs,
        "Cannot create operation because there is no operation definition registered with the name '" ~ opType ~ "'");

    auto op = new Operation(opType, deps, attribs, mod, line);

    return op;
}

private
{
    OpDef[string] mOpDefs;

    TensorType makeJudgement(const(Operation) op)
    {
        auto def = op.opType in mOpDefs;

        enforce(def !is null, "Cannot make judgement for unknown operation '" ~ op.opType() ~ "'");

        return def.judge(op);
    }
}