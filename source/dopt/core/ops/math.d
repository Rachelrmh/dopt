/**
    Contains constructors for common math operations.

    Authors: Henry Gouk
*/
module dopt.core.ops.math;

import std.algorithm;
import std.conv;
import std.functional;
import std.range;

import dopt.core.ops;
import dopt.core.types;

package
{
    void initialize()
    {
        void registerPointwiseBinary(string opName)
        {
            bool verifier(const(Operation) op)
            {
                return op.deps.length == 2 && op.deps[0].outputType == op.deps[1].outputType;
            }

            TensorType judge(const(Operation) op)
            {
                return TensorType(op.deps[0].outputType);
            }

            registerOperation(opName, OpDef(&verifier, &judge));
        }

        void registerPointwiseUnary(string opName)
        {
            bool verifier(const(Operation) op)
            {
                return true;
            }

            TensorType judge(const(Operation) op)
            {
                return TensorType(op.deps[0].outputType);
            }

            registerOperation(opName, OpDef(&verifier, &judge));
        }

        foreach(opName; chain(arith, comp, binfunc))
        {
            registerPointwiseBinary(opName);
        }

        foreach(opName; unfunc)
        {
            registerPointwiseUnary(opName);
        }

        registerOperation("matmul", OpDef(toDelegate(&verifyMatmul), toDelegate(&judgeMatmul)));
        registerOperation("sum", OpDef(toDelegate(&verifySum), toDelegate(&judgeSum)));
    }
}

private
{
    immutable string[] arith = ["add", "sub", "mul", "div"];
    immutable string[] comp = ["lt", "lte", "gt", "gte", "eq", "neq"];
    immutable string[] binfunc = ["max", "min", "pow"];
    immutable string[] unfunc = ["neg", "abs", "sgn", "exp", "log", "sqrt"];

    string createAllCtors()
    {
        string createOpCtor(string opName, size_t numDeps)
        {
            auto params = iota(0, numDeps)
                        .map!(x => "const(Operation) p" ~ x.to!string)
                        .joiner(", ")
                        .to!string();

            auto args = iota(0, numDeps)
                    .map!(x => "p" ~ x.to!string)
                    .joiner(", ")
                    .to!string;

            return "
                    Operation " ~ opName ~ "(" ~ params ~ ", string mod = __MODULE__, size_t line = __LINE__)
                    {
                        return createOperation(\"" ~ opName ~ "\", [" ~ args ~ "], null, mod, line);
                    }
                ";
        }

        string binctors = chain(arith, comp, binfunc)
                         .map!(x => createOpCtor(x, 2))
                         .joiner("\n")
                         .to!string;

        auto unctors = unfunc
                      .map!(x => createOpCtor(x, 1))
                      .joiner("\n")
                      .to!string;

        return binctors ~ unctors;
    }

    bool verifyMatmul(const(Operation) op)
    {
        return op.deps.length == 2
            && op.deps[0].outputType.rank == 2
            && op.deps[1].outputType.rank == 2
            && op.deps[0].outputType.elementType == op.deps[1].outputType.elementType
            && op.deps[0].outputType.shape[1] == op.deps[1].outputType.shape[0];
    }

    TensorType judgeMatmul(const(Operation) op)
    {
        return TensorType(op.deps[0].outputType.elementType,
            [op.deps[0].outputType.shape[0], op.deps[1].outputType.shape[1]]);
    }

    bool verifySum(const(Operation) op)
    {
        if(op.deps.length != 1)
        {
            return false;
        }

        if(("axes" in op.attributes) is null || op.attributes["axes"].peek!(const(size_t)[]) is null)
        {
            return false;
        }

        auto axes = op.attributes["axes"].get!(const(size_t)[]);

        return axes.all!(x => x < op.deps[0].rank) &&
               axes.map!(x => size_t(x)).array().sort().uniq().count() == axes.length;
    }

    TensorType judgeSum(const(Operation) op)
    {
        auto t = op.deps[0].outputType;
        auto axes = op.attributes["axes"].get!(const(size_t)[]);

        auto newShape = t
                       .shape
                       .zip(iota(0, t.shape.length))
                       .filter!(x => !axes.canFind(x[1]))
                       .map!(x => x[0])
                       .array();

        return TensorType(t.elementType, newShape);
    }
}

mixin(createAllCtors());

Operation matmul(const(Operation) lhs, const(Operation) rhs, string mod = __MODULE__, size_t line = __LINE__)
{
    return createOperation("matmul", [lhs, rhs], null, mod, line);
}

Operation sum(const(Operation) op, const(size_t)[] axes = [], string mod = __MODULE__, size_t line = __LINE__)
{
    import std.variant : Variant;

    if(op.rank == 0)
    {
        return op.reshape(op.shape);
    }

    if(axes.length == 0)
    {
        axes = iota(0, op.deps[0].rank).array();
    }
    
    return createOperation("sum", [op], ["axes": Variant(axes)], mod, line);
}