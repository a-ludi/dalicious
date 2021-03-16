/**
    Some additional mathematical functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.math;

import dalicious.algorithm;
import std.algorithm;
import std.algorithm : stdMean = mean;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.functional;
import std.math;
import std.math : stdFloor = floor;
import std.range;
import std.string;
import std.traits;
import std.typecons;

debug import std.stdio : writeln;


/**
    Standardized value that signifies undefined for all numeric types. It is
    `NaN` for floating point types and the maximum representable value for
    integer types.

    See_also: `isUndefined`
*/
template undefined(T) if (isNumeric!T)
{
    static if (is(typeof(T.nan)))
        enum undefined = T.nan;
    else static if (is(typeof(T.max)))
        enum undefined = T.max;
    else
        static assert(0, "`undefined` is undefined for type " ~ E.stringof);
}


/**
    Check if `value` has the standardized undefined value.

    See_also:   `undefined`
    Returns:    True iff value is undefined according to `undefined`.
*/
bool isUndefined(T)(T value) if (is(typeof(undefined!T)))
{
    static if (isNaN(undefined!T))
        return isNaN(value);
    else
        return value < undefined!T;
}


/// Calculate the mean of range.
ElementType!Range mean(Range)(Range values) if (isForwardRange!Range)
{
    auto sum = values.save.sum;
    auto length = values.walkLength.to!(ElementType!Range);

    return cast(typeof(return)) (sum / length);
}

unittest
{
    {
        auto values = [2, 4, 8];
        assert(values.mean == 4);
    }
    {
        auto values = [1.0, 2.0, 3.0, 4.0];
        assert(values.mean == 2.5);
    }
}

/// Calculate the weighted mean of values.
double mean(Values, Weights)(Values values, Weights weights)
    if (isInputRange!Values && isForwardRange!Weights)
{
    enum zeroWeight = cast(ElementType!Weights) 0;

    auto weightedSum = zip(StoppingPolicy.requireSameLength, values, weights)
        .map!(pair => (pair[0] * pair[1]).to!double)
        .sum;
    auto totalWeight = weights.sum;

    return weightedSum / totalWeight;
}

unittest
{
    {
        auto values = [2, 4, 6];
        auto equalWeights = [1, 1, 1];
        auto weights = [3, 4, 1];

        assert(mean(values, equalWeights) == mean(values));
        assert(mean(values, weights) == 3.5);
    }
    {
        auto values = [1.0, 2.0, 3.0, 4.0];
        auto weights = [4.0, 3.0, 2.0, 1.0];

        assert(mean(values, weights) == 2.0);
    }
}

/**
    Calculate the quantiles of values mapped with `fun`. The elements of
    `values` are passed to `fun` before calculating the quantiles. This
    removes the necessity of creating a proxy range.

    All quantiles are `undefined` if `values` is empty.

    Returns:    Range of quantiles. The returned range `isRandomAccessRange`,
                `hasSlicing` and has the same length as `ps`.
*/
auto quantiles(alias fun = "a", Range, F)(Range values, F[] ps...)
    if (isFloatingPoint!F)
in (ps.all!"0 < a && a < 1", "all ps must be 0 < p < 1")
{
    alias f = unaryFun!fun;
    alias E = typeof(f(values.front));

    auto sortedValues = values.sort!((a, b) => f(a) < f(b));
    auto mappedValues = sortedValues.map!f;
    auto n = mappedValues.length;

    auto calcQuantile(double q)
    {
        if (n == 0)
        {
            return undefined!E;
        }
        else if (isInteger(n * q))
        {
            auto i = cast(size_t) round(n * q);

            if (0 < i && i < n)
                return (mappedValues[i - 1] + mappedValues[i]) / 2;
            else if (i == n)
                return mappedValues[n - 1];
            else
                return mappedValues[0];
        }
        else
        {
            return mappedValues[cast(size_t) stdFloor(n * q)];
        }
    }

    auto _quantiles = ps.map!calcQuantile;

    alias Q = typeof(_quantiles);
    static assert(isBidirectionalRange!Q);
    static assert(isRandomAccessRange!Q);
    static assert(hasSlicing!Q);
    static assert(hasLength!Q);

    return _quantiles;
}

unittest {
    auto values = [4, 2, 8];
    assert(values.quantiles(
        1.0/3.0,
        2.0/3.0,
    ).equal([
        3,
        6,
    ]));
}

unittest {
    auto values = [4, 2, 8, 0, 13];
    assert(values.quantiles(
        1/4f,
        2/4f,
        3/4f,
    ).equal([
        2,
        4,
        8,
    ]));
}

unittest {
    auto values = [4, 2, 8];
    assert(values.quantiles(
        1/3f,
        2/3f,
    ).equal([
        3,
        6,
    ]));
}

unittest {
    auto values = [4, 2, 8];
    assert(values.quantiles(
        1e-6,
        1 - 1e-6,
    ).equal([
        2,
        8,
    ]));
}

unittest {
    double[] values = [];
    assert(values.quantiles(
        0.36,
        0.46,
        0.53,
        0.85,
        0.95,
    ).all!isUndefined);
}

unittest {
    auto values = [0.839124, 0.506056, 0.661209, 0.235569, 0.747409, 0.182975,
                   0.348437, 0.322757, 0.237597, 0.624974, 0.490688];
    assert(values.quantiles(
        0.36,
        0.46,
        0.53,
        0.85,
        0.95,
    ).equal!approxEqual([
        0.322757,
        0.490688,
        0.490688,
        0.747409,
        0.839124,
    ]));
}


/**
    Calculate the median of `fun`ed values. The elements of `values` are
    passed to `fun` before calculating the median. This removes the necessity
    of creating a proxy range.

    Returns:    Median of range or `undefined` iff `values` is empty.
*/
auto median(alias fun = "a", Range)(Range values)
{
    return quantiles!fun(values, 0.5)[0];
}

unittest {
    auto values = [4, 2, 8];
    assert(values.median == 4);
}

unittest {
    auto values = [4, 3, 2, 8];
    assert(values.median == 3);
}

unittest {
    auto values = [4, 6, 2, 8];
    assert(values.median == 5);
}

unittest {
    auto values = [2, 1, 3, 0, 4, 9, 8, 5, 6, 3, 9];
    assert(values.median == 4);
}

unittest {
    auto values = [2.0, 1.0, 4.0, 3.0];
    assert(values.median == 2.5);
}

unittest {
    auto values = [2.0, 1.0, 4.0, 3.0, 5.0];
    assert(values.median == 3.0);
}

unittest {
    double[] values = [];
    assert(isUndefined(values.median));
}


/// Calculate the standard deviation (`sigma^^2`) of the sample.
ElementType!Range stddev(Range)(Range values) if (isForwardRange!Range)
{
    auto sampleMean = mean(values.save);

    return stddev(values, sampleMean);
}

/// ditto
ElementType!Range stddev(Range, M)(Range values, M sampleMean) if (isForwardRange!Range)
{
    return values.save.map!(n => (n - sampleMean)^^2).sum / cast(ElementType!Range) values.save.walkLength;
}


/**
    Eliminate outliers the deviate more than expected from the sample median.
    A data point `x` is an outlier iff

        abs(x - median) > lambda*sqrt(stddev(values))

    Params:
        values      Range of values.
        lambda      Level of confidence.
    Returns:
        `values` without outliers.
*/
auto eliminateOutliers(R, N)(R values, N lambda) if (isForwardRange!R)
{
    return eliminateOutliers(values, lambda, mean(values.save));
}

/// ditto
auto eliminateOutliers(R, N, M)(
    R values,
    N lambda,
    M sampleMean,
) if (isForwardRange!R)
{
    return eliminateOutliers(values, lambda, sampleMean, stddev(values.save, sampleMean));
}

/// ditto
auto eliminateOutliers(R, N, M, S)(
    R values,
    N lambda,
    M sampleMean,
    S sampleStddev,
) if (isForwardRange!R)
{
    return eliminateOutliers(values, lambda, sampleMean, sampleStddev, median(values.save));
}

/// ditto
auto eliminateOutliers(R, N, M, S, D)(
    R values,
    N lambda,
    M sampleMean,
    S sampleStddev,
    D sampleMedian,
) if (isForwardRange!R)
{
    auto threshold = lambda * sqrt(cast(double) sampleStddev);

    return values.filter!(n => absdiff(n, sampleMedian) <= threshold);
}

unittest
{
    assert(equal([1].eliminateOutliers(1), [1]));
}


/**
    Calculate the Nxx (e.g. N50) of values. `values` will be `sort`ed in the
    process. If this is undesired the range must be `dup`licated beforehands.
    The elements of `values` are passed to `map` before calculating the
    median. This removes the necessity of creating a proxy range.

    The CTFE-version differs from the dynamic implementation only in a static
    check for a valid value of `xx` and the order of arguments.
    The CTFE-version should be preferred if possible because it looks nicer.

    Returns:    Nxx statistic or `undefined` value iff `values` is empty or
                `map`ped `values` sum up to less than `totalSize`.
*/
auto N(real xx, alias map = "a", Range, Num)(Range values, Num totalSize)
{
    static assert(0 < xx && xx < 100, "N" ~ xx.to!string ~ " is undefined");

    return N!map(values, xx, totalSize);
}

auto N(alias map = "a", Range, Num)(Range values, real xx, Num totalSize)
{
    assert(0 < xx && xx < 100, format!"N%f is undefined"(xx));

    alias _map = unaryFun!map;
    alias E = typeof(_map(values.front));

    if (values.length == 0)
        return undefined!E;

    auto xxPercentile = xx/100.0 * totalSize;
    auto sortedValues = values.sort!((a, b) => _map(a) > _map(b));
    auto targetIndex = sortedValues
        .cumulativeFold!((acc, el) => acc + _map(el))(cast(E) 0)
        .countUntil!((partialSum, total) => partialSum >= total)(xxPercentile);

    if (targetIndex < 0 || values.length <= targetIndex)
        return undefined!E;
    else
        return _map(sortedValues[targetIndex]);
}

unittest
{
    {
        auto totalSize = 54;
        auto values = [2, 3, 4, 5, 6, 7, 8, 9, 10];
        enum N50 = 8;
        enum N10 = 10;

        assert(N(values, 50, totalSize) == N50);
        assert(N!50(values, totalSize) == N50);
        assert(N(values, 10, totalSize) == N10);
        assert(N!10(values, totalSize) == N10);
    }
    {
        auto totalSize = 32;
        auto values = [2, 2, 2, 3, 3, 4, 8, 8];
        enum N50 = 8;

        assert(N(values, 50, totalSize) == N50);
        assert(N!50(values, totalSize) == N50);
    }
}


enum RoundingMode : byte
{
    floor,
    round,
    ceil,
}

/**
    Round x upward according to base, ie. returns the next integer larger or
    equal to x which is divisible by base.

    Returns: x rounded upward according to base.
*/
Integer ceil(Integer)(in Integer x, in Integer base) pure nothrow
        if (isIntegral!Integer)
{
    return x % base == 0
        ? x
        : (x / base + 1) * base;
}

///
unittest
{
    assert(ceil(8, 10) == 10);
    assert(ceil(32, 16) == 32);
    assert(ceil(101, 100) == 200);
}

/**
    Round x downward according to base, ie. returns the next integer smaller or
    equal to x which is divisible by base.

    Returns: x rounded downward according to base.
*/
Integer floor(Integer)(in Integer x, in Integer base) pure nothrow
        if (isIntegral!Integer)
{
    return (x / base) * base;
}

///
unittest
{
    assert(floor(8, 10) == 0);
    assert(floor(32, 16) == 32);
    assert(floor(101, 100) == 100);
}

/// Returns the absolute difference between two numbers.
Num absdiff(Num)(in Num a, in Num b) pure nothrow if (isNumeric!Num)
{
    return a > b
        ? a - b
        : b - a;
}

///
unittest
{
    assert(absdiff(2UL, 3UL) == 1UL);
    assert(absdiff(-42, 13) == 55);
    assert(absdiff(2.5, 5) == 2.5);
}

/// Returns the result of `ceil(a / b)` but uses integer arithmetic only.
Integer ceildiv(Integer)(in Integer a, in Integer b) pure nothrow if (isIntegral!Integer)
{
    Integer resultSign = (a < 0) ^ (b < 0) ? -1 : 1;

    return resultSign < 0 || a % b == 0
        ? a / b
        : a / b + resultSign;
}

///
unittest
{
    assert(ceildiv(0, 3) == 0);
    assert(ceildiv(1UL, 3UL) == 1UL);
    assert(ceildiv(2L, 3L) == 1L);
    assert(ceildiv(3U, 3U) == 1U);
    assert(ceildiv(4, 3) == 2);
    assert(ceildiv(-4, 4) == -1);
    assert(ceildiv(-4, 3) == -1);
}


bool isInteger(F)(F x, F eps = 1e-5) pure nothrow @safe
    if (isFloatingPoint!F)
in (0 <= eps)
{
    return abs(x - round(x)) <= eps;
}


/// Convert to given type without errors by bounding values to target type
/// limits.
IntTo boundedConvert(IntTo, IntFrom)(IntFrom value) pure nothrow @safe @nogc
    if (isIntegral!IntTo && isIntegral!IntFrom)
{
    static if (isSigned!IntFrom == isSigned!IntTo)
    {
        if (IntTo.min <= value && value <= IntTo.max)
            return cast(IntTo) value;
        else if (IntTo.min > value)
            return IntTo.min;
        else
            return IntTo.max;
    }
    else static if (isSigned!IntFrom)
    {
        static assert(isUnsigned!IntTo);

        if (value < 0)
            return IntTo.min;
        else if (cast(Unsigned!IntFrom) value < IntTo.max)
            return cast(IntTo) value;
        else
            return IntTo.max;
    }
    else
    {
        static assert(isUnsigned!IntFrom && isSigned!IntTo);

        if (value < cast(Unsigned!IntTo) IntTo.max)
            return cast(IntTo) value;
        else
            return IntTo.max;
    }
}

///
unittest
{
    assert((0).boundedConvert!uint == 0u);
    assert((42).boundedConvert!uint == 42u);
    assert((int.max).boundedConvert!uint == cast(uint) int.max);
    assert((-1).boundedConvert!uint == 0u);
}

unittest
{
    import std.meta;

    alias IntTypes = AliasSeq!(
        byte,
        ubyte,
        short,
        ushort,
        int,
        uint,
        long,
        ulong,
        //cent,
        //ucent,
    );

    static foreach (alias IntFrom; IntTypes)
        static foreach (alias IntTo; IntTypes)
        {
            assert(IntFrom(0).boundedConvert!IntTo == IntTo(0));
            assert(IntFrom(42).boundedConvert!IntTo == IntTo(42));
        }

    // IntFrom = byte
    assert(boundedConvert!byte      (byte.max) == byte.max);
    assert(boundedConvert!ubyte     (byte.max) == byte.max);
    assert(boundedConvert!short     (byte.max) == byte.max);
    assert(boundedConvert!ushort    (byte.max) == byte.max);
    assert(boundedConvert!int       (byte.max) == byte.max);
    assert(boundedConvert!uint      (byte.max) == byte.max);
    assert(boundedConvert!long      (byte.max) == byte.max);
    assert(boundedConvert!ulong     (byte.max) == byte.max);
    assert(boundedConvert!byte      (byte.min) == byte.min);
    assert(boundedConvert!ubyte     (byte.min) == ubyte.min);
    assert(boundedConvert!short     (byte.min) == byte.min);
    assert(boundedConvert!ushort    (byte.min) == ushort.min);
    assert(boundedConvert!int       (byte.min) == byte.min);
    assert(boundedConvert!uint      (byte.min) == uint.min);
    assert(boundedConvert!long      (byte.min) == byte.min);
    assert(boundedConvert!ulong     (byte.min) == ulong.min);

    // IntFrom = ubyte
    assert(boundedConvert!byte      (ubyte.max) == byte.max);
    assert(boundedConvert!ubyte     (ubyte.max) == ubyte.max);
    assert(boundedConvert!short     (ubyte.max) == ubyte.max);
    assert(boundedConvert!ushort    (ubyte.max) == ubyte.max);
    assert(boundedConvert!int       (ubyte.max) == ubyte.max);
    assert(boundedConvert!uint      (ubyte.max) == ubyte.max);
    assert(boundedConvert!long      (ubyte.max) == ubyte.max);
    assert(boundedConvert!ulong     (ubyte.max) == ubyte.max);

    // IntFrom = int
    assert(boundedConvert!byte      (int.max) == byte.max);
    assert(boundedConvert!ubyte     (int.max) == ubyte.max);
    assert(boundedConvert!short     (int.max) == short.max);
    assert(boundedConvert!ushort    (int.max) == ushort.max);
    assert(boundedConvert!int       (int.max) == int.max);
    assert(boundedConvert!uint      (int.max) == int.max);
    assert(boundedConvert!long      (int.max) == int.max);
    assert(boundedConvert!ulong     (int.max) == int.max);
    assert(boundedConvert!byte      (int.min) == byte.min);
    assert(boundedConvert!ubyte     (int.min) == ubyte.min);
    assert(boundedConvert!short     (int.min) == short.min);
    assert(boundedConvert!ushort    (int.min) == ushort.min);
    assert(boundedConvert!int       (int.min) == int.min);
    assert(boundedConvert!uint      (int.min) == uint.min);
    assert(boundedConvert!long      (int.min) == int.min);
    assert(boundedConvert!ulong     (int.min) == uint.min);

    // IntFrom = uint
    assert(boundedConvert!byte      (uint.max) == byte.max);
    assert(boundedConvert!ubyte     (uint.max) == ubyte.max);
    assert(boundedConvert!short     (uint.max) == short.max);
    assert(boundedConvert!ushort    (uint.max) == ushort.max);
    assert(boundedConvert!int       (uint.max) == int.max);
    assert(boundedConvert!uint      (uint.max) == uint.max);
    assert(boundedConvert!long      (uint.max) == uint.max);
    assert(boundedConvert!ulong     (uint.max) == uint.max);
}


/// Convert to given type without errors by bounding values to target type
/// limits.
int compareIntegers(Int)(Int lhs, Int rhs) pure nothrow @safe @nogc if (isIntegral!Int)
{
    static if (isSigned!Int)
    {
        static if (Int.sizeof <= int.sizeof)
            return cast(int) (lhs - rhs);
        else
            return boundedConvert!int(lhs - rhs);
    }
    else
    {
        static assert(isUnsigned!Int);

        if (lhs >= rhs)
            return boundedConvert!int(lhs - rhs);
        else
            return -1;
    }
}

///
unittest
{
    assert(compareIntegers( 1, 1) == 0);
    assert(compareIntegers(-1, 1) < 0);
    assert(compareIntegers( 1, -1) > 0);
    assert(compareIntegers(int.min, int.min) == 0);
}

unittest
{
    assert(compareIntegers(0UL, 0UL) == 0);
    assert(compareIntegers(0UL, ulong.max) < 0);
    assert(compareIntegers(ulong.max, 0UL) > 0);
    assert(compareIntegers(ulong.max, ulong.max) == 0);
}


class EdgeExistsException : Exception
{
    pure nothrow @nogc @safe this(
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable nextInChain = null,
    )
    {
        super("edge cannot be inserted: edge already exists", file, line, nextInChain);
    }
}

class NodeExistsException : Exception
{
    pure nothrow @nogc @safe this(
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable nextInChain = null,
    )
    {
        super("node cannot be inserted: node already exists", file, line, nextInChain);
    }
}

class MissingEdgeException : Exception
{
    pure nothrow @nogc @safe this(
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable nextInChain = null,
    )
    {
        super("edge not found", file, line, nextInChain);
    }
}

class MissingNodeException : Exception
{
    pure nothrow @nogc @safe this(
        string file = __FILE__,
        size_t line = __LINE__,
        Throwable nextInChain = null,
    )
    {
        super("node not found", file, line, nextInChain);
    }
}

/// This structure represents a graph with optional edge
/// payloads. The graph is represented as a list of edges which is
/// particularly suited for sparse graphs. While the set of nodes is fixed the
/// set of edges is mutable.
struct Graph(Node, Weight = void, Flag!"isDirected" isDirected = No.isDirected, EdgePayload = void)
{
    static enum isWeighted = !is(Weight == void);
    static enum hasEdgePayload = !is(EdgePayload == void);

    static struct Edge
    {
        protected Node _start;
        protected Node _end;

        static if (isWeighted)
            Weight weight;

        static if (hasEdgePayload)
            EdgePayload payload;

        /// Construct an edge.
        this(Node start, Node end)
        {
            this._start = start;
            this._end = end;

            static if (!isDirected)
            {
                if (end < start)
                {
                    swap(this._start, this._end);
                }
            }
        }

        static if (isWeighted)
        {
            /// ditto
            this(Node start, Node end, Weight weight)
            {
                this(start, end);
                this.weight = weight;
            }
        }

        static if (hasEdgePayload && !is(EdgePayload : Weight))
        {
            /// ditto
            this(Node start, Node end, EdgePayload payload)
            {
                this(start, end);
                this.payload = payload;
            }
        }

        static if (isWeighted && hasEdgePayload)
        {
            /// ditto
            this(Node start, Node end, Weight weight, EdgePayload payload)
            {
                this(start, end);
                this.weight = weight;
                this.payload = payload;
            }
        }

        /// Get the start of this edge. For undirected graphs this is the
        /// smaller of both incident nodes.
        @property Node start() const pure nothrow
        {
            return _start;
        }

        /// Get the end of this edge. For undirected graphs this is the
        /// larger of both incident nodes.
        @property Node end() const pure nothrow
        {
            return _end;
        }

        /**
            Get target of this edge beginning at node `from`. For undirected
            graphs returns the other node of this edge.

            Throws: MissingNodeException if this edge does not start in node `from`.
        */
        Node target(Node from) const
        {
            static if (isDirected)
            {
                if (start == from)
                {
                    return end;
                }
                else
                {
                    throw new MissingNodeException();
                }
            }
            else
            {
                if (start == from)
                {
                    return end;
                }
                else if (end == from)
                {
                    return start;
                }
                else
                {
                    throw new MissingNodeException();
                }
            }
        }

        /**
            Get source of this edge beginning at node `from`. For undirected
            graphs returns the other node of this edge.

            Throws: MissingNodeException if this edge does not end in node `from`.
        */
        static if (isDirected)
        {
            Node source(Node from) const
            {
                if (end == from)
                {
                    return start;
                }
                else
                {
                    throw new MissingNodeException();
                }
            }
        }
        else
        {
            alias source = target;
        }

        /// Two edges are equal iff their incident nodes (and weight) are the
        /// same.
        bool opEquals(in Edge other) const pure nothrow
        {
            static if (isWeighted)
            {
                return this.start == other.start && this.end == other.end
                    && this.weight == other.weight;
            }
            else
            {
                return this.start == other.start && this.end == other.end;
            }
        }

        /// Orders edge lexicographically by `start`, `end`(, `weight`).
        int opCmp(in Edge other) const pure nothrow
        {
            static if (isWeighted)
            {
                return cmpLexicographically!(
                    typeof(this),
                    "a.start",
                    "a.end",
                    "a.weight",
                )(this, other);
            }
            else
            {
                return cmpLexicographically!(
                    typeof(this),
                    "a.start",
                    "a.end",
                )(this, other);
            }
        }

        private int compareNodes(in Edge other) const pure nothrow
        {
            return cmpLexicographically!(
                typeof(this),
                "a.start",
                "a.end",
            )(this, other);
        }

        /**
            Returns the node that is connects this edge with other edge. In
            case of undirected graphs this is just the common node of both
            edges; in directed case this is the end node of this edge if it
            matches the start node of other edge.

            Throws: MissingNodeException if the connecting node is undefined.
        */
        Node getConnectingNode(in Edge other) const
        {
            static if (isDirected)
            {
                if (this.end == other.start)
                {
                    return this.end;
                }
            }
            else
            {
                if (this.end == other.start || this.end == other.end)
                {
                    return this.end;
                }
                else if (this.start == other.start || this.start == other.end)
                {
                    return this.start;
                }
            }

            throw new MissingNodeException();
        }
    }

    static bool orderByNodes(in Edge a, in Edge b) nothrow pure
    {
        return a.compareNodes(b) < 0;
    }

    static bool groupByNodes(in Edge a, in Edge b) nothrow pure
    {
        return a.compareNodes(b) == 0;
    }

    /// Construct an edge for this graph.
    static Edge edge(T...)(T args)
    {
        return Edge(args);
    }

    protected Node[] _nodes;
    protected Appender!(Edge[]) _edges;

    /// The set (ordered list) of nodes.
    @property const(Node[]) nodes() const nothrow pure
    {
        return _nodes;
    }

    private @property void nodes(Node[] nodes)
    {
        nodes.sort();

        this._nodes = nodes.uniq.array;
    }

    /// Get the set (ordered list) of edges in this graph.
    @property auto edges() nothrow pure
    {
        return chain(_edges.data);
    }

    /// ditto
    @property auto edges() const nothrow pure
    {
        return chain(_edges.data);
    }

    /**
        Construct a graph from a set of nodes (and edges). Modifies `nodes`
        while sorting but releases it after construction.

        Throws: MissingNodeException if an edge has a node that is not present
                in this graph .
        Throws: EdgeExistsException if an edge already exists when trying
                inserting it.
    */
    this(Node[] nodes)
    {
        this.nodes = nodes;
    }

    /// ditto
    this(Node[] nodes, Edge[] edges)
    {
        this(nodes);

        _edges.reserve(edges.length);
        foreach (edge; edges)
        {
            add(this, edge);
        }
    }

    this(this)
    {
        _nodes = _nodes.dup;
    }

    /// Add a set of edges to this graph without any checks.
    void bulkAddForce(R)(R edges) if (isForwardRange!R && is(ElementType!R == Edge))
    {
        this._edges ~= edges;
        _edges.data.sort;
    }

    /// Add an edge to this graph.
    /// See_Also: `Edge add(Graph, Edge)`
    void opOpAssign(string op)(Edge edge) if (op == "~")
    {
        add(this, edge);
    }

    /// Some pre-defined conflict handlers for `add`.
    static struct ConflictStrategy
    {
        static if (isWeighted)
        {
            /// Return an edge with sum of both weights. If given payload will be
            /// kept from existingEdge .
            static Edge sumWeights(Edge existingEdge, Edge newEdge)
            {
                existingEdge.weight += newEdge.weight;

                return existingEdge;
            }

            ///
            unittest
            {
                auto g1 = Graph!(int, int)([1, 2]);
                alias CS = g1.ConflictStrategy;

                g1 ~= g1.edge(1, 2, 1);

                auto addedEdge = g1.add!(CS.sumWeights)(g1.edge(1, 2, 1));

                assert(addedEdge.weight == 2);
            }
        }

        /// Throw `EdgeExistsException`.
        static inout(Edge) error(inout(Edge) existingEdge, inout(Edge) newEdge)
        {
            throw new EdgeExistsException();
        }

        ///
        unittest
        {
            auto g1 = Graph!int([1, 2]);
            alias CS = g1.ConflictStrategy;

            g1 ~= g1.edge(1, 2);

            assertThrown!EdgeExistsException(g1.add!(CS.error)(g1.edge(1, 2)));
        }

        /// Replace the existingEdge by newEdge.
        static inout(Edge) replace(inout(Edge) existingEdge, inout(Edge) newEdge)
        {
            return newEdge;
        }

        ///
        unittest
        {
            auto g1 = Graph!(int, int)([1, 2]);
            alias CS = g1.ConflictStrategy;

            g1 ~= g1.edge(1, 2, 1);

            auto addedEdge = g1.add!(CS.replace)(g1.edge(1, 2, 2));

            assert(addedEdge.weight == 2);
        }

        /// Keep existingEdge – discard newEdge.
        static inout(Edge) keep(inout(Edge) existingEdge, inout(Edge) newEdge)
        {
            return existingEdge;
        }

        ///
        unittest
        {
            auto g1 = Graph!(int, int)([1, 2]);
            alias CS = g1.ConflictStrategy;

            g1 ~= g1.edge(1, 2, 1);

            auto addedEdge = g1.add!(CS.keep)(g1.edge(1, 2, 2));

            assert(addedEdge.weight == 1);
        }
    }

    /// Forcibly add an edge to this graph.
    protected Edge forceAdd(Edge edge)
    {
        _edges ~= edge;
        _edges.data.sort;

        return edge;
    }

    /// Replace an edge in this graph.
    protected Edge replaceEdge(in size_t edgeIdx, Edge newEdge)
    {
        auto shouldSort = _edges.data[edgeIdx] != newEdge;

        _edges.data[edgeIdx] = newEdge;

        if (shouldSort)
        {
            _edges.data.sort;
        }

        return newEdge;
    }

    /// Check if edge/node exists in this graph. Ignores the weight if weighted.
    bool opBinaryRight(string op)(in Node node) const pure nothrow if (op == "in")
    {
        auto sortedNodes = assumeSorted(nodes);

        return sortedNodes.contains(node);
    }

    /// ditto
    bool has(in Node node) const pure nothrow
    {
        return node in this;
    }

    /// Check if edge exists in this graph. Only the `start` and `end` node
    /// will be compared.
    bool opBinaryRight(string op)(in Edge edge) const pure nothrow if (op == "in")
    {
        auto sortedEdges = assumeSorted!orderByNodes(edges);

        return sortedEdges.contains(edge);
    }

    /// ditto
    bool has(in Edge edge) const pure nothrow
    {
        return edge in this;
    }

    /// Get the designated edge from this graph. Only the `start` and `end`
    /// node will be compared.
    auto ref get(in Edge edge)
    {
        auto sortedEdges = assumeSorted!orderByNodes(edges);
        auto existingEdges = sortedEdges.equalRange(edge);

        if (existingEdges.empty)
        {
            throw new MissingEdgeException();
        }
        else
        {
            return existingEdges.front;
        }
    }

    ///
    unittest
    {
        auto g1 = Graph!(int, int)([1, 2]);

        auto e1 = g1.edge(1, 2, 1);

        g1 ~= e1;

        assert(g1.get(g1.edge(1, 2)) == e1);
        assertThrown!MissingEdgeException(g1.get(g1.edge(1, 1)));
    }

    /// Returns the index of node `n` in the list of nodes.
    size_t indexOf(in Node n) const
    {
        auto sortedNodes = assumeSorted(nodes);
        auto tristectedNodes = sortedNodes.trisect(n);

        if (tristectedNodes[1].empty)
        {
            throw new MissingNodeException();
        }

        return tristectedNodes[0].length;
    }

    ///
    unittest
    {
        auto g1 = Graph!(int, int)([1, 2]);

        assert(g1.indexOf(1) == 0);
        assert(g1.indexOf(2) == 1);
        assertThrown!MissingNodeException(g1.indexOf(3));
    }

    /// Returns the index of node `n` in the list of nodes.
    size_t indexOf(in Edge edge) const
    {
        auto sortedEdges = assumeSorted!orderByNodes(edges);
        auto trisectedEdges = sortedEdges.trisect(edge);

        if (trisectedEdges[1].empty)
        {
            throw new MissingEdgeException();
        }

        return trisectedEdges[0].length;
    }

    ///
    unittest
    {
        auto g1 = Graph!(int, int)([1, 2]);

        auto e1 = g1.edge(1, 2, 1);

        g1 ~= e1;

        assert(g1.indexOf(g1.edge(1, 2)) == 0);
        assertThrown!MissingEdgeException(g1.indexOf(g1.edge(1, 1)));
    }

    static if (isDirected)
    {
        /// Returns a range of in/outgoing edges of node `n`.
        auto inEdges(Node n) nothrow pure
        {
            return _edges.data[].filter!(e => e.end == n);
        }

        /// ditto
        auto inEdges(Node n) const nothrow pure
        {
            return edges[].filter!(e => e.end == n);
        }

        /// ditto
        auto outEdges(Node n) nothrow pure
        {
            return _edges.data[].filter!(e => e.start == n);
        }

        /// ditto
        auto outEdges(Node n) const nothrow pure
        {
            return edges[].filter!(e => e.start == n);
        }

        ///
        unittest
        {
            import std.algorithm : equal;

            auto g1 = Graph!(int, void, Yes.isDirected)([1, 2, 3]);

            g1 ~= g1.edge(1, 1);
            g1 ~= g1.edge(1, 2);
            g1 ~= g1.edge(2, 2);
            g1 ~= g1.edge(2, 3);

            assert(g1.inEdges(1).equal([
                g1.edge(1, 1),
            ]));
            assert(g1.outEdges(1).equal([
                g1.edge(1, 1),
                g1.edge(1, 2),
            ]));
            assert(g1.inEdges(2).equal([
                g1.edge(1, 2),
                g1.edge(2, 2),
            ]));
            assert(g1.outEdges(2).equal([
                g1.edge(2, 2),
                g1.edge(2, 3),
            ]));
            assert(g1.inEdges(3).equal([
                g1.edge(2, 3),
            ]));
            assert(g1.outEdges(3).empty);
        }

        /// Get the in/out degree of node `n`.
        size_t inDegree(Node n) const nothrow pure
        {
            return inEdges(n).walkLength;
        }

        /// ditto
        size_t outDegree(Node n) const nothrow pure
        {
            return outEdges(n).walkLength;
        }

        ///
        unittest
        {
            auto g1 = Graph!(int, void, Yes.isDirected)([1, 2, 3]);

            g1 ~= g1.edge(1, 1);
            g1 ~= g1.edge(1, 2);
            g1 ~= g1.edge(2, 2);
            g1 ~= g1.edge(2, 3);

            assert(g1.inDegree(1) == 1);
            assert(g1.outDegree(1) == 2);
            assert(g1.inDegree(2) == 2);
            assert(g1.outDegree(2) == 2);
            assert(g1.inDegree(3) == 1);
            assert(g1.outDegree(3) == 0);
        }
    }
    else
    {
        /// Returns a range of all edges incident to node `n`.
        auto incidentEdges(Node n) nothrow pure
        {
            return _edges.data[].filter!(e => e.start == n || e.end == n);
        }

        /// ditto
        auto incidentEdges(Node n) const nothrow pure
        {
            return edges[].filter!(e => e.start == n || e.end == n);
        }

        /// ditto
        alias inEdges = incidentEdges;

        /// ditto
        alias outEdges = incidentEdges;

        ///
        unittest
        {
            import std.algorithm : equal;

            auto g1 = Graph!int([1, 2, 3]);

            g1 ~= g1.edge(1, 1);
            g1 ~= g1.edge(1, 2);
            g1 ~= g1.edge(2, 2);
            g1 ~= g1.edge(2, 3);

            assert(g1.incidentEdges(1).equal([
                g1.edge(1, 1),
                g1.edge(1, 2),
            ]));
            assert(g1.incidentEdges(2).equal([
                g1.edge(1, 2),
                g1.edge(2, 2),
                g1.edge(2, 3),
            ]));
            assert(g1.incidentEdges(3).equal([
                g1.edge(2, 3),
            ]));
        }

        IncidentEdgesCache allIncidentEdges()
        {
            return IncidentEdgesCache(this);
        }

        static struct IncidentEdgesCache
        {
            alias G = Graph!(Node, Weight, isDirected, EdgePayload);
            G graph;
            Edge[][] incidentEdges;

            this(G graph)
            {
                this.graph = graph;
                collectAllIncidentEdges();
            }

            private void collectAllIncidentEdges()
            {
                preallocateMemory();

                size_t startIdx;
                size_t endIdx;
                foreach (edge; graph._edges.data)
                {
                    if (graph._nodes[startIdx] < edge.start)
                        endIdx = startIdx;
                    while (graph._nodes[startIdx] < edge.start)
                        ++startIdx;
                    if (endIdx < startIdx)
                        endIdx = startIdx;
                    while (graph._nodes[endIdx] < edge.end)
                        ++endIdx;

                    incidentEdges[startIdx] ~= edge;
                    // Avoid double-counting of loops
                    if (startIdx != endIdx)
                        incidentEdges[endIdx] ~= edge;
                }
            }

            void preallocateMemory()
            {
                auto degreesCache = graph.allDegrees();
                Edge[] buffer;
                buffer.length = degreesCache.degrees.sum;
                incidentEdges.length = degreesCache.degrees.length;

                size_t sliceBegin;
                size_t startIdx;
                foreach (degree; degreesCache)
                {
                    incidentEdges[startIdx] = buffer[sliceBegin .. sliceBegin + degree];
                    incidentEdges[startIdx].length = 0;

                    sliceBegin += degree;
                    ++startIdx;
                }
            }

            static if (!is(Node == size_t))
                ref inout(Edge[]) opIndex(in Node node) inout
                {
                    return incidentEdges[graph.indexOf(node)];
                }

            ref inout(Edge[]) opIndex(in size_t nodeIdx) inout
            {
                return incidentEdges[nodeIdx];
            }

            int opApply(scope int delegate(Edge[]) yield)
            {
                int result = 0;

                foreach (currentIncidentEdges; incidentEdges)
                {
                    result = yield(currentIncidentEdges);
                    if (result)
                        break;
                }

                return result;
            }

            int opApply(scope int delegate(Node, Edge[]) yield)
            {
                int result = 0;

                foreach (i, currentIncidentEdges; incidentEdges)
                {
                    result = yield(graph._nodes[i], currentIncidentEdges);
                    if (result)
                        break;
                }

                return result;
            }
        }

        /// Get the `adjacencyList` of this graph where nodes are represented
        /// by their index in the nodes list.
        size_t[][] adjacencyList() const
        {
            size_t[][] _adjacencyList;
            _adjacencyList.length = nodes.length;
            size_t[] targetsBuffer;
            targetsBuffer.length = 2 * edges.length;

            foreach (i, node; _nodes)
            {
                auto bufferRest = edges
                    .filter!(e => e.start == node || e.end == node)
                    .map!(edge => indexOf(edge.target(node)))
                    .copy(targetsBuffer);
                _adjacencyList[i] = targetsBuffer[0 .. $ - bufferRest.length];
                _adjacencyList[i].sort;
                targetsBuffer = bufferRest;
            }

            return _adjacencyList;
        }

        ///
        unittest
        {
            auto g1 = Graph!int([1, 2, 3, 4]);

            g1 ~= g1.edge(1, 1);
            g1 ~= g1.edge(1, 2);
            g1 ~= g1.edge(2, 2);
            g1 ~= g1.edge(2, 3);
            g1 ~= g1.edge(2, 4);
            g1 ~= g1.edge(3, 4);

            assert(g1.adjacencyList() == [
                [0, 1],
                [0, 1, 2, 3],
                [1, 3],
                [1, 2],
            ]);
        }

        /// Get the degree of node `n`.
        size_t degree(Node n) const nothrow pure
        {
            return incidentEdges(n).walkLength;
        }

        /// ditto
        alias inDegree = degree;

        /// ditto
        alias outDegree = degree;

        DegreesCache allDegrees() const
        {
            return DegreesCache(this);
        }

        static struct DegreesCache
        {
            alias G = Graph!(Node, Weight, isDirected, EdgePayload);
            const(G) graph;
            size_t[] degrees;

            this(in G graph)
            {
                this.graph = graph;
                collectAllDegrees();
            }

            private void collectAllDegrees()
            {
                degrees.length = graph._nodes.length;

                size_t startIdx;
                size_t endIdx;
                foreach (edge; graph._edges.data)
                {
                    if (graph._nodes[startIdx] < edge.start)
                        endIdx = startIdx;
                    while (graph._nodes[startIdx] < edge.start)
                        ++startIdx;
                    if (endIdx < startIdx)
                        endIdx = startIdx;
                    while (graph._nodes[endIdx] < edge.end)
                        ++endIdx;

                    ++degrees[startIdx];
                    // Avoid double-counting of loops
                    if (startIdx != endIdx)
                        ++degrees[endIdx];
                }
            }

            static if (!is(Node == size_t))
                size_t opIndex(in Node node) const
                {
                    return degrees[graph.indexOf(node)];
                }

            size_t opIndex(in size_t nodeIdx) const
            {
                return degrees[nodeIdx];
            }

            int opApply(scope int delegate(size_t) yield) const
            {
                int result = 0;

                foreach (degree; degrees)
                {
                    result = yield(degree);
                    if (result)
                        break;
                }

                return result;
            }

            int opApply(scope int delegate(Node, size_t) yield) const
            {
                int result = 0;

                foreach (i, degree; degrees)
                {
                    result = yield(graph._nodes[i], degree);
                    if (result)
                        break;
                }

                return result;
            }
        }
    }
}

///
unittest
{
    //   +-+  +-+
    //   \ /  \ /
    //   (1)--(2)
    auto g1 = Graph!int([1, 2]);

    g1 ~= g1.edge(1, 1);
    g1 ~= g1.edge(1, 2);
    g1.add(g1.edge(2, 2));

    assert(g1.edge(1, 1) in g1);
    assert(g1.edge(1, 2) in g1);
    assert(g1.edge(2, 1) in g1);
    assert(g1.has(g1.edge(2, 2)));
    assert(g1.allDegrees().degrees == [2, 2]);
    assert(g1.allIncidentEdges().incidentEdges == [
        [g1.edge(1, 1), g1.edge(1, 2)],
        [g1.edge(1, 2), g1.edge(2, 2)],
    ]);

    //   0.5     0.5
    //   +-+     +-+
    //   \ /     \ /
    //   (1)-----(2)
    //       1.0
    auto g2 = Graph!(int, double)([1, 2]);

    g2 ~= g2.edge(1, 1, 0.5);
    g2 ~= g2.edge(1, 2, 1.0);
    g2.add(g2.edge(2, 2, 0.5));

    assert(g2.edge(1, 1) in g2);
    assert(g2.edge(1, 2) in g2);
    assert(g2.edge(2, 1) in g2);
    assert(g2.has(g2.edge(2, 2)));
    assert(g2.allDegrees().degrees == [2, 2]);
    assert(g2.allIncidentEdges().incidentEdges == [
        [g2.edge(1, 1, 0.5), g2.edge(1, 2, 1.0)],
        [g2.edge(1, 2, 1.0), g2.edge(2, 2, 0.5)],
    ]);

    //   0.5     0.5
    //   +-+     +-+
    //   \ v     v /
    //   (1)---->(2)
    //       1.0
    auto g3 = Graph!(int, double, Yes.isDirected)([1, 2]);

    g3 ~= g3.edge(1, 1, 0.5);
    g3 ~= g3.edge(1, 2, 1.0);
    g3.add(g3.edge(2, 2, 0.5));

    assert(g3.edge(1, 1) in g3);
    assert(g3.edge(1, 2) in g3);
    assert(!(g3.edge(2, 1) in g3));
    assert(g3.has(g3.edge(2, 2)));

    //   +-+   +-+
    //   \ v   v /
    //   (1)-->(2)
    auto g4 = Graph!(int, void, Yes.isDirected)([1, 2]);

    g4 ~= g4.edge(1, 1);
    g4 ~= g4.edge(1, 2);
    g4.add(g4.edge(2, 2));

    assert(g4.edge(1, 1) in g4);
    assert(g4.edge(1, 2) in g4);
    assert(!(g4.edge(2, 1) in g4));
    assert(g4.has(g4.edge(2, 2)));

    //   +-+  +-+
    //   \ /  \ /
    //   (1)--(2)
    //
    // payload(1, 1) = [1];
    // payload(1, 2) = [2];
    // payload(2, 2) = [3];
    auto g5 = Graph!(int, void, No.isDirected, int[])([1, 2]);

    g5 ~= g5.edge(1, 1, [1]);
    g5 ~= g5.edge(1, 2, [2]);
    g5.add(g5.edge(2, 2, [3]));

    assert(g5.edge(1, 1) in g5);
    assert(g5.get(g5.edge(1, 1)).payload == [1]);
    assert(g5.edge(1, 2) in g5);
    assert(g5.get(g5.edge(1, 2)).payload == [2]);
    assert(g5.edge(2, 1) in g5);
    assert(g5.get(g5.edge(2, 1)).payload == [2]);
    assert(g5.has(g5.edge(2, 2)));
    assert(g5.get(g5.edge(2, 2)).payload == [3]);
    assert(g5.allDegrees().degrees == [2, 2]);
    assert(g5.allIncidentEdges().incidentEdges == [
        [g5.edge(1, 1), g5.edge(1, 2)],
        [g5.edge(1, 2), g5.edge(2, 2)],
    ]);
}

///
unittest
{
    //     -1     1         1
    // (1)----(2)---(3) (4)---(5) (6)
    size_t[] contigs = [1, 2, 3, 4, 5, 6];
    auto contigGraph = Graph!(size_t, int)([1, 2, 3, 4, 5, 6]);

    contigGraph.add(contigGraph.edge(1, 2, -1));
    contigGraph.add(contigGraph.edge(2, 3, 1));
    contigGraph.add(contigGraph.edge(4, 5, 1));

    foreach (contig; contigs)
    {
        assert(contigGraph.degree(contig) <= 2);
    }
    assert(contigGraph.allDegrees().degrees == [1, 2, 1, 1, 1, 0]);
    assert(contigGraph.allIncidentEdges().incidentEdges == [
        [contigGraph.edge(1, 2, -1)],
        [contigGraph.edge(1, 2, -1), contigGraph.edge(2, 3, 1)],
        [contigGraph.edge(2, 3, 1)],
        [contigGraph.edge(4, 5, 1)],
        [contigGraph.edge(4, 5, 1)],
        [],
    ]);
}

/// Add a set of edges to this graph and merge mutli-edges using `merge`.
void bulkAdd(alias merge, G, R)(ref G graph, R edges)
        if (is(G : Graph!Params, Params...) && isForwardRange!R && is(ElementType!R == G.Edge))
{
    alias Edge = G.Edge;
    alias ReturnTypeMerge = typeof(merge(new Edge[0]));
    static assert(is(ReturnTypeMerge == Edge), "expected `Edge merge(Edge[] multiEdge)`");

    graph.bulkAddForce(edges);

    auto bufferRest = graph
        ._edges
        .data
        .sliceBy!(G.groupByNodes)
        .map!(unaryFun!merge)
        .copy(graph._edges.data);
    graph._edges.shrinkTo(graph._edges.data.length - bufferRest.length);
}

///
unittest
{
    auto g1 = Graph!(int, int)([1, 2]);

    static g1.Edge sumWeights(g1.Edge[] multiEdge)
    {
        auto sumOfWeights = multiEdge.map!"a.weight".sum;
        auto mergedEdge = multiEdge[0];
        mergedEdge.weight = sumOfWeights;

        return mergedEdge;
    }

    auto edges = [
        g1.edge(1, 2, 1),
        g1.edge(1, 2, 1),
        g1.edge(1, 2, 1),
        g1.edge(2, 3, 2),
        g1.edge(2, 3, 2),
        g1.edge(3, 4, 3),
    ];
    g1.bulkAdd!sumWeights(edges);
    assert(g1.edges == [
        g1.edge(1, 2, 3),
        g1.edge(2, 3, 4),
        g1.edge(3, 4, 3),
    ]);
}

/// Add an edge to this graph and handle existing edges with `handleConflict`.
/// The handler must have this signature `Edge handleConflict(Edge, Edge)`.
G.Edge add(alias handleConflict = 1337, G)(ref G graph, G.Edge edge)
        if (is(G : Graph!Params, Params...))
{
    static if (isCallable!handleConflict)
        alias handleConflict_ = binaryFun!handleConflict;
    else
        alias handleConflict_ = binaryFun!(G.ConflictStrategy.error);

    if (!graph.has(edge.start) || !graph.has(edge.end))
    {
        throw new MissingNodeException();
    }

    auto sortedEdges = assumeSorted!(G.orderByNodes)(graph._edges.data);
    auto trisectedEdges = sortedEdges.trisect(edge);
    auto existingEdges = trisectedEdges[1];
    auto existingEdgeIdx = trisectedEdges[0].length;

    if (existingEdges.empty)
    {
        return graph.forceAdd(edge);
    }
    else
    {
        auto newEdge = handleConflict_(existingEdges.front, edge);

        return graph.replaceEdge(existingEdgeIdx, newEdge);
    }
}

///
unittest
{
    auto g1 = Graph!(int, int)([1, 2]);

    auto e1 = g1.edge(1, 2, 1);
    auto e2 = g1.edge(1, 2, 2);

    g1 ~= e1;

    assertThrown!EdgeExistsException(g1.add(e2));

    with (g1.ConflictStrategy)
    {
        g1.add!replace(e2);

        assert(g1.get(g1.edge(1, 2)) == e2);

        g1.add!keep(e1);

        assert(g1.get(g1.edge(1, 2)) == e2);

        g1.add!sumWeights(e2);

        assert(g1.get(g1.edge(1, 2)).weight == 2 * e2.weight);
    }
}

void filterEdges(alias pred, G)(ref G graph) if (is(G : Graph!Params, Params...))
{
    auto bufferRest = graph
        ._edges
        .data
        .filter!pred
        .copy(graph._edges.data);
    graph._edges.shrinkTo(graph._edges.data.length - bufferRest.length);
}

void mapEdges(alias fun, G)(ref G graph) if (is(G : Graph!Params, Params...))
{
    foreach (ref edge; graph._edges.data)
        edge = unaryFun!fun(edge);

    graph._edges.data.sort();
}


struct UndirectedGraph(Node, Weight = void)
{
    static enum isWeighted = !is(Weight == void);

    static if (isWeighted)
        alias adjacency_t = Weight;
    else
        alias adjacency_t = bool;


    static struct Edge
    {
        protected Node _start;
        protected Node _end;

        static if (isWeighted)
            Weight weight;

        /// Construct an edge.
        this(Node start, Node end) pure nothrow @safe
        {
            this._start = start;
            this._end = end;

            if (end < start)
                swap(this._start, this._end);
        }

        static if (isWeighted)
        {
            /// ditto
            this(Node start, Node end, Weight weight) pure nothrow @safe
            {
                this(start, end);
                this.weight = weight;
            }
        }


        private @property adjacency_t adjacencyValue() pure nothrow @safe @nogc
        {
            static if (isWeighted)
                return weight;
            else
                return true;
        }


        /// Get the start of this edge, i.e. the smaller of both incident
        /// nodes.
        @property Node start() const pure nothrow @safe
        {
            return _start;
        }

        /// Get the end of this edge, i.e. the larger of both incident nodes.
        @property Node end() const pure nothrow @safe
        {
            return _end;
        }

        /**
            Returns the other node of this edge.

            Throws: MissingNodeException if this edge does not coincide with `from`.
        */
        Node target(Node from) const
        {
            if (from == start)
                return end;
            else if (from == end)
                return start;
            else
                throw new MissingNodeException();
        }

        /// ditto
        alias source = target;

        /// Two edges are equal iff their incident nodes are the same.
        bool opEquals(in Edge other) const pure nothrow
        {
            return this.start == other.start && this.end == other.end;
        }

        /// Orders edge lexicographically by `start`, `end`.
        int opCmp(in Edge other) const pure nothrow
        {
            return cmpLexicographically!(
                typeof(this),
                "a.start",
                "a.end",
            )(this, other);
        }

        /**
            Returns the node that is common to this and other.

            Throws: MissingNodeException if there this and other do not share
                a common node.
        */
        Node getCommonNode(in Edge other) const
        {
            import std.algorithm : among;

            if (this.end.among(other.start, other.end))
                return this.end;
            else if (this.start.among(other.start, other.end))
                return this.start;
            else
                throw new MissingNodeException();
        }
    }

    /// Construct an edge for this graph.
    static Edge edge(T...)(T args)
    {
        return Edge(args);
    }


    protected bool[Node] _nodes;
    protected adjacency_t[Node][Node] _adjacency;


    /// Returns a list of the nodes in this graph.
    @property Node[] nodes() const nothrow pure
    {
        return _nodes.keys;
    }


    /// Returns a list of all edges in this graph.
    @property auto edges() nothrow pure
    {
        static if (isWeighted)
            alias buildEdge = (start, end, weight) => Edge(start, end, weight);
        else
            alias buildEdge = (start, end, weight) => Edge(start, end);

        return _adjacency
            .keys()
            .map!(start => _adjacency[start]
                .keys()
                .map!(end => buildEdge(start, end, _adjacency[start][end]))
            )
            .joiner;
    }

    /// ditto
    @property auto edges() const nothrow pure
    {
        static if (isWeighted)
            alias buildEdge = (start, end, weight) => cast(const) Edge(start, end, cast() weight);
        else
            alias buildEdge = (start, end, weight) => cast(const) Edge(start, end);

        return _adjacency
            .keys()
            .map!(start => _adjacency[start]
                .keys()
                .map!(end => buildEdge(start, end, _adjacency[start][end]))
            )
            .joiner;
    }


    /**
        Construct a graph from a set of nodes (and edges).

        Throws: NodeExistsException if a node already exists when trying
                to insert it.
        Throws: EdgeExistsException if an edge already exists when trying
                to insert it.
    */
    this(Node[] nodes)
    {
        foreach (node; nodes)
            this.addNode(node);
    }

    /// ditto
    this(Node[] nodes, Edge[] edges)
    {
        this(nodes);

        foreach (edge; edges)
            this.addEdge(edge);
    }


    /// Inserts node into the node list if not yet present.
    void requireNode(Node node) nothrow @safe
    {
        requireNode(node);
    }

    /// ditto
    void requireNode(ref Node node) nothrow @safe
    {
        this._nodes[node] = true;
    }


    private static T _throw(T, E)(ref T _)
    {
        throw new E();
    }


    /**
        Inserts node into the node list throwing an exception if already
        present.

        Throws: NodeExistsException if node already present.
    */
    void addNode(Node node) @safe
    {
        addNode(node);
    }

    /// ditto
    void addNode(ref Node node) @safe
    {
        this._nodes.update(
            node,
            { return true; },
            &_throw!(bool, NodeExistsException),
        );
    }


    /**
        Inserts edge into the graph thrwoing an exception if already present.

        Throws: EdgeExistsException if edge already present.
    */
    void addEdge(Edge edge) @safe
    {
        addEdge(edge._start, edge._end, edge.adjacencyValue);
        addEdge(edge._end, edge._start, edge.adjacencyValue);
        requireNode(edge._start);
        requireNode(edge._end);
    }


    private void addEdge(ref Node start, ref Node end, adjacency_t adjacencyValue) @safe
    {
        import std.exception : enforce;

        _adjacency.update(start,
            {
                adjacency_t[Node] secondLevelAdjacency;

                secondLevelAdjacency[end] = adjacencyValue;

                return secondLevelAdjacency;
            },
            (ref adjacency_t[Node] secondLevelAdjacency) {
                secondLevelAdjacency.update(
                    end,
                    delegate () { return adjacencyValue; },
                    &_throw!(adjacency_t, EdgeExistsException),
                );

                return secondLevelAdjacency;
            },
        );

        requireNode(start);
        requireNode(end);
    }
}


class EmptySetException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

struct NaturalNumberSet
{
    private static enum partSize = 8 * size_t.sizeof;
    private static enum size_t firstBit = 1;
    private static enum size_t lastBit = firstBit << (partSize - 1);
    private static enum size_t emptyPart = 0;
    private static enum size_t fullPart = ~emptyPart;

    private size_t[] parts;
    private size_t numSetBits;

    this(size_t initialNumElements, Flag!"addAll" addAll = No.addAll)
    {
        reserveFor(initialNumElements);

        if (addAll)
        {
            foreach (i; 0 .. initialNumElements / partSize)
                parts[i] = fullPart;
            foreach (i; initialNumElements / partSize .. initialNumElements)
                add(i);
            numSetBits = initialNumElements;
        }
    }

    static NaturalNumberSet create(size_t[] initialElements...)
    {
        if (initialElements.length == 0)
            return NaturalNumberSet();

        auto set = NaturalNumberSet(initialElements.maxElement);

        foreach (i; initialElements)
            set.add(i);
        set.numSetBits = set.countSetBits();

        return set;
    }

    this(this) pure nothrow @safe
    {
        parts = parts.dup;
    }

    private this(size_t[] parts) pure nothrow @safe @nogc
    {
        this.parts = parts;
        this.numSetBits = countSetBits();
    }

    private bool inBounds(in size_t n) const pure nothrow @safe @nogc
    {
        return n < capacity;
    }

    void reserveFor(in size_t n) pure nothrow @safe
    {
        if (parts.length == 0)
        {
            parts.length = max(1, ceildiv(n, partSize));
        }

        while (!inBounds(n))
        {
            parts.length *= 2;
        }
    }

    @property size_t capacity() const pure nothrow @safe @nogc
    {
        return parts.length * partSize;
    }

    private size_t partIdx(in size_t n) const pure nothrow @safe @nogc
    {
        return n / partSize;
    }

    private size_t idxInPart(in size_t n) const pure nothrow @safe @nogc
    {
        return n % partSize;
    }

    private size_t itemMask(in size_t n) const pure nothrow @safe @nogc
    {
        return firstBit << idxInPart(n);
    }

    static size_t inverse(in size_t n) pure nothrow @safe @nogc
    {
        return n ^ fullPart;
    }

    void add(in size_t n) pure nothrow
    {
        import core.bitop : testSetBit = bts;

        reserveFor(n);

        if (testSetBit(parts.ptr, n) == 0)
            ++numSetBits;
    }

    void remove(in size_t n)
    {
        import core.bitop : testResetBit = btr;

        if (!inBounds(n))
            return;

        if (testResetBit(parts.ptr, n) != 0)
            --numSetBits;
    }

    bool has(in size_t n) const pure nothrow @nogc
    {
        import core.bitop : testBit = bt;

        if (!inBounds(n))
            return false;

        return testBit(parts.ptr, n) != 0;
    }

    bool opBinaryRight(string op)(in size_t n) const pure nothrow if (op == "in")
    {
        return this.has(n);
    }

    bool empty() const pure nothrow
    {
        return parts.all!(part => part == emptyPart);
    }

    void clear() pure nothrow
    {
        foreach (ref part; parts)
            part = emptyPart;
        numSetBits = 0;
    }

    bool opBinary(string op)(in NaturalNumberSet other) const pure nothrow if (op == "==")
    {
        auto numCommonParts = min(this.parts.length, other.parts.length);

        foreach (i; 0 .. numCommonParts)
        {
            if (this.parts[i] != other.parts[i])
                return false;
        }

        static bool hasEmptyTail(ref in NaturalNumberSet set, in size_t tailStart)
        {
            foreach (i; tailStart .. set.parts.length)
                if (set.parts[i] != emptyPart)
                    return false;

            return true;
        }

        if (this.parts.length > numCommonParts)
            return hasEmptyTail(this, numCommonParts);
        if (other.parts.length > numCommonParts)
            return hasEmptyTail(other, numCommonParts);

        return true;
    }

    bool opBinary(string op)(in NaturalNumberSet other) const pure nothrow if (op == "in")
    {
        auto numCommonParts = min(this.parts.length, other.parts.length);

        foreach (i; 0 .. numCommonParts)
            if ((this.parts[i] & other.parts[i]) != this.parts[i])
                return false;

        static bool hasEmptyTail(ref in NaturalNumberSet set, in size_t tailStart)
        {
            foreach (i; tailStart .. set.parts.length)
                if (set.parts[i] != emptyPart)
                    return false;

            return true;
        }

        if (this.parts.length > numCommonParts)
            return hasEmptyTail(this, numCommonParts);

        return true;
    }

    NaturalNumberSet opBinary(string op)(in NaturalNumberSet other) const pure nothrow if (op.among("|", "^", "&"))
    {
        NaturalNumberSet result;
        result.parts.length = max(this.parts.length, other.parts.length);

        auto numCommonParts = min(this.parts.length, other.parts.length);

        foreach (i; 0 .. numCommonParts)
            result.parts[i] = mixin("this.parts[i] " ~ op ~ " other.parts[i]");

        static if (op.among("|", "^"))
        {
            if (this.parts.length > numCommonParts)
                result.parts[numCommonParts .. $] = this.parts[numCommonParts .. $];
            if (other.parts.length > numCommonParts)
                result.parts[numCommonParts .. $] = other.parts[numCommonParts .. $];
        }

        result.numSetBits = result.countSetBits();

        return result;
    }

    bool intersects(in NaturalNumberSet other) const pure nothrow
    {
        auto numCommonParts = min(this.parts.length, other.parts.length);

        foreach (i; 0 .. numCommonParts)
        {
            if ((this.parts[i] & other.parts[i]) != emptyPart)
                return true;
        }

        return false;
    }

    @property size_t size() const pure nothrow @safe @nogc
    {
        return numSetBits;
    }

    private size_t countSetBits() const pure nothrow @safe @nogc
    {
        import core.bitop : numSetBits = popcnt;

        return parts.map!numSetBits.sum;
    }

    size_t minElement() const
    {
        import core.bitop : getLeastSignificantSetBit = bsf;

        foreach (i, part; parts)
            if (part != emptyPart)
                return i * partSize + getLeastSignificantSetBit(part);

        throw new EmptySetException("empty set has no minElement");
    }

    size_t maxElement() const
    {
        import core.bitop : getMostSignificantSetBit = bsr;

        foreach_reverse (i, part; parts)
            if (part != emptyPart)
                return i * partSize + getMostSignificantSetBit(part);

        throw new EmptySetException("empty set has no maxElement");
    }

    unittest
    {
        foreach (i; 0 .. 2 * NaturalNumberSet.partSize)
        {
            NaturalNumberSet set;

            set.add(i + 5);
            set.add(i + 7);

            assert(set.minElement() == i + 5);
            assert(set.maxElement() == i + 7);
        }
    }

    /// Returns a range of the elements in this set. The elements are ordered
    /// ascending.
    @property auto elements() const pure nothrow @nogc
    {
        import core.bitop : BitRange;

        static struct ElementsRange
        {
            private const size_t[] parts;
            private BitRange impl;
            alias impl this;


            this(const size_t[] parts) pure nothrow @nogc
            {
                this.parts = parts;
                this.impl = BitRange(parts.ptr, parts.length * partSize);
            }


            void popFront() pure nothrow @nogc
            {
                assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

                impl.popFront();
            }


            @property size_t front() pure nothrow @safe @nogc
            {
                assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

                return impl.front;
            }


            @property bool empty() const pure nothrow @safe @nogc
            {
                return impl.empty;
            }


            @property ElementsRange save() const pure nothrow @nogc
            {
                return ElementsRange(parts);
            }
        }

        return ElementsRange(parts);
    }

    ///
    unittest
    {
        import std.algorithm : equal;
        import std.range : iota;

        NaturalNumberSet set;
        auto someNumbers = iota(set.partSize).filter!"a % 3 == 0";

        foreach (i; someNumbers)
        {
            set.add(i);
        }

        assert(equal(someNumbers, set.elements));
    }

    /// The set may be modified while iterating:
    unittest
    {
        import std.algorithm : equal;
        import std.range : iota;

        enum numElements = 64;
        auto set = NaturalNumberSet(numElements, Yes.addAll);

        foreach (i; set.elements)
        {
            if (i % 10 == 0)
                set.remove(i + 1);
        }

        auto expectedNumbers = iota(numElements).filter!"a == 0 || !((a - 1) % 10 == 0)";
        assert(equal(expectedNumbers, set.elements));
    }

    string toString() const pure
    {
        return format("[%(%d,%)]", this.elements);
    }
}

unittest
{
    NaturalNumberSet set;

    // add some numbers
    foreach (i; 0 .. set.partSize)
    {
        if (i % 2 == 0)
        {
            set.add(i);
        }
    }

    // force extension of set
    foreach (i; set.partSize .. 2 * set.partSize)
    {
        if (i % 3 == 0)
        {
            set.add(i);
        }
    }

    // validate presence
    foreach (i; 0 .. 2 * set.partSize)
    {
        if (i / set.partSize == 0 && i % 2 == 0)
        {
            assert(set.has(i));
        }
        else if (i / set.partSize == 1 && i % 3 == 0)
        {
            assert(set.has(i));
        }
        else
        {
            assert(!set.has(i));
        }
    }
}

unittest
{
    size_t[] bits = chain(
        0UL.repeat(270),
        only(4194304UL),
        0UL.repeat(5),
        only(131072UL),
    ).array;
    auto set = NaturalNumberSet(bits);

    assert(equal(set.elements, [17302, 17681]));
}

/**
    Find all maximal connected components of a graph-like structure. The
    predicate `isConnected` will be evaluated `O(n^^2)` times in the
    worst-case and `Ω(n)` in the best case. In expectation it will be
    evaluated `θ(n*log(n))`.

    Params:
        isConnected =   binary predicate that evaluates to true iff two nodes,
                        represented as indices, are connected
        numNodes    =   total number of nodes in the graph

    Returns:    range of maxmimally connected components represented as
                `NaturalNumberSet`s
*/
auto findMaximallyConnectedComponents(alias isConnected)(in size_t numNodes)
{
    return MaximalConnectedComponents!(binaryFun!isConnected)(numNodes);
}

///
unittest
{
    import std.algorithm : equal;
    import std.range : only;

    alias modEqv(size_t m) = (a, b) => (a % m) == (b % m);
    alias clusterByThreshold(size_t t) = (a, b) => (a < t) == (b < t);

    assert(equal(
        findMaximallyConnectedComponents!(modEqv!5)(15),
        only(
            NaturalNumberSet.create(0, 5, 10),
            NaturalNumberSet.create(1, 6, 11),
            NaturalNumberSet.create(2, 7, 12),
            NaturalNumberSet.create(3, 8, 13),
            NaturalNumberSet.create(4, 9, 14),
        ),
    ));
    assert(equal(
        findMaximallyConnectedComponents!(modEqv!3)(15),
        only(
            NaturalNumberSet.create(0, 3, 6, 9, 12),
            NaturalNumberSet.create(1, 4, 7, 10, 13),
            NaturalNumberSet.create(2, 5, 8, 11, 14),
        ),
    ));
    assert(equal(
        findMaximallyConnectedComponents!(clusterByThreshold!10)(15),
        only(
            NaturalNumberSet.create(0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
            NaturalNumberSet.create(10, 11, 12, 13, 14),
        ),
    ));
}

///
unittest
{
    import std.algorithm : equal;
    import std.range : only;

    auto connectivity = [
        [false, false, false, true ],
        [false, false, true , false],
        [false, true , false, false],
        [true , false, false, false],
    ];
    alias isConnected = (i, j) => connectivity[i][j];

    assert(equal(
        findMaximallyConnectedComponents!isConnected(4),
        only(
            NaturalNumberSet.create(0, 3),
            NaturalNumberSet.create(1, 2),
        ),
    ));
}

private struct MaximalConnectedComponents(alias isConnected)
{

    const(size_t) numNodes;
    NaturalNumberSet unvisited;
    NaturalNumberSet currentComponent;

    this(in size_t numNodes)
    {
        this.numNodes = numNodes;
        this.unvisited = NaturalNumberSet(numNodes, Yes.addAll);
        this.currentComponent = NaturalNumberSet(numNodes);

        if (!empty)
            popFront();
    }

    void popFront()
    {
        assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

        currentComponent.clear();

        if (unvisited.empty)
            return;

        auto seedNode = unvisited.minElement;

        maximizeConnectedComponent(seedNode);
    }

    private void maximizeConnectedComponent(size_t node)
    {
        currentComponent.add(node);
        unvisited.remove(node);

        foreach (nextNode; unvisited.elements)
            if (isConnected(node, nextNode))
                maximizeConnectedComponent(nextNode);
    }

    @property NaturalNumberSet front()
    {
        assert(!empty, "Attempting to fetch the front an empty " ~ typeof(this).stringof);

        return currentComponent;
    }

    @property bool empty() const pure nothrow
    {
        return unvisited.empty && currentComponent.empty;
    }
}

/**
    Find a cycle base of an undirected graph using the Paton's
    algorithm.

    The algorithm is described in

    > K. Paton, An algorithm for finding a fundamental set of cycles
    > for an undirected linear graph, Comm. ACM 12 (1969), pp. 514-518.

    and the implementation is adapted from the [Java implementation][1] of
    K. Paton originally licensed under [Apache License 2.0][2].

    [1]: https://code.google.com/archive/p/niographs/
    [2]: http://www.apache.org/licenses/LICENSE-2.0

    Returns: range of cycles in the graph represented as arrays of node indices
*/
auto findCyclicSubgraphs(G)(
    G graph,
    G.IncidentEdgesCache incidentEdgesCache = G.IncidentEdgesCache.init,
)
    if (is(G : Graph!Params, Params...))
{
    auto node(in size_t idx)
    {
        return graph.nodes[idx];
    }

    version(assert) void assertValidCycle(in size_t[] cycle)
    {
        enum errorMsg = "not a cycle";

        assert(
            cycle.length > 0 && graph.edge(node(cycle[0]), node(cycle[$ - 1])) in graph,
            errorMsg
        );

        foreach (pair; cycle.slide!(No.withPartial)(2))
            assert(graph.edge(node(pair[0]), node(pair[1])) in graph, errorMsg);
    }

    auto numNodes = graph.nodes.length;

    NaturalNumberSet[] used;
    used.length = numNodes;

    long[] parent;
    parent.length = numNodes;
    parent[] = -1;

    size_t[] stack;
    stack.reserve(numNodes);

    auto cycles = appender!(size_t[][]);

    if (incidentEdgesCache == G.IncidentEdgesCache.init)
        incidentEdgesCache = graph.allIncidentEdges();

    foreach (rootIdx, root; graph.nodes)
    {
        // Loop over the connected
        // components of the graph.
        if (parent[rootIdx] >= 0)
            continue;

        // Prepare to walk the spanning tree.
        parent[rootIdx] = rootIdx;
        used[rootIdx].reserveFor(numNodes);
        used[rootIdx].add(rootIdx);
        stack ~= rootIdx;

        // Do the walk. It is a BFS with
        // a LIFO instead of the usual
        // FIFO. Thus it is easier to
        // find the cycles in the tree.
        while (stack.length > 0)
        {
            auto currentIdx = stack[$ - 1];
            --stack.length;
            auto current = node(currentIdx);
            auto currentUsed = &used[currentIdx];

            foreach (edge; incidentEdgesCache[currentIdx])
            {
                auto neighbour = edge.target(current);
                auto neighbourIdx = graph.indexOf(neighbour);
                auto neighbourUsed = &used[neighbourIdx];

                if (neighbourUsed.empty)
                {
                    // found a new node
                    parent[neighbourIdx] = currentIdx;
                    neighbourUsed.reserveFor(numNodes);
                    neighbourUsed.add(currentIdx);

                    stack ~= neighbourIdx;
                }
                else if (neighbourIdx == currentIdx)
                {
                    // found a self loop
                    auto cycle = [currentIdx];
                    cycles ~= cycle;
                    version(assert) assertValidCycle(cycle);
                }
                else if (!currentUsed.has(neighbourIdx))
                {
                    // found a cycle
                    auto cycle = appender!(size_t[]);
                    cycle ~= neighbourIdx;
                    cycle ~= currentIdx;

                    auto p = parent[currentIdx];
                    for (; !neighbourUsed.has(p); p = parent[p])
                        cycle ~= p;

                    cycle ~= p;
                    cycles ~= cycle.data;
                    version(assert) assertValidCycle(cycle.data);
                    neighbourUsed.add(currentIdx);
                }
            }
        }
    }

    return cycles.data;
}

///
unittest
{
    alias G = Graph!int;

    //   __
    //   \ \
    //    `-0 -- 1 -- 2 -- 3
    //      |       / |    |
    //      |      /  |    |
    //      4 -- 5 -- 6    7
    auto g = G([0, 1, 2, 3, 4, 5, 6, 7], [
        G.edge(0, 0),
        G.edge(0, 1),
        G.edge(0, 4),
        G.edge(1, 2),
        G.edge(2, 3),
        G.edge(2, 5),
        G.edge(2, 6),
        G.edge(3, 7),
        G.edge(4, 5),
        G.edge(5, 6),
    ]);
    auto cycles = g.findCyclicSubgraphs();

    import std.algorithm : equal;

    assert(cycles.equal([
        [0],
        [2, 6, 5],
        [1, 2, 5, 4, 0],
    ]));
}

/**
    Find all maximal cliques in a graph represented by `adjacencyList`.
    The implementation is based on version 1 of the Bron-Kerbosch algorithm [1].

    [1]: Bron, C.; Kerbosch, J. (1973), "Algorithm 457: finding all cliques
         of an undirected graph", Communications of the ACM, 16 (9): 575–577,
         doi:10.1145/362342.362367.

    Returns: list of sets of nodes each representing a maximal clique
*/
auto findAllCliques(in size_t[][] adjacencyList)
{
    return BronKerboschVersion1(adjacencyList);
}

///
unittest
{
    auto g = Graph!int([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    g.add(g.edge(0, 1));
    g.add(g.edge(0, 2));
    g.add(g.edge(1, 2));
    g.add(g.edge(1, 7));
    g.add(g.edge(1, 8));
    g.add(g.edge(2, 3));
    g.add(g.edge(3, 4));
    g.add(g.edge(3, 5));
    g.add(g.edge(3, 6));
    g.add(g.edge(4, 5));
    g.add(g.edge(4, 6));
    g.add(g.edge(5, 6));
    g.add(g.edge(6, 7));
    g.add(g.edge(7, 8));

    auto cliques = array(findAllCliques(g.adjacencyList()));

    assert(cliques == [
        [0, 1, 2],
        [1, 7, 8],
        [2, 3],
        [3, 4, 5, 6],
        [6, 7],
        [9],
    ]);
}

private struct BronKerboschVersion1
{
    const size_t[][] adjacencyList;

    int opApply(scope int delegate(size_t[]) yield)
    {
        size_t[] clique;
        clique.reserve(adjacencyList.length);

        auto candidates = NaturalNumberSet(adjacencyList.length, Yes.addAll);
        auto not = NaturalNumberSet(adjacencyList.length);

        return extendClique(clique, candidates, not, yield);
    }

    private int extendClique(
        size_t[] clique,
        NaturalNumberSet candidates,
        NaturalNumberSet not,
        scope int delegate(size_t[]) yield,
    )
    {
        import std.stdio;

        if (not.empty && candidates.empty)
            return clique.length == 0 ? 0 : yield(clique);

        int result;

        foreach (candidate; candidates.elements)
        {
            clique ~= candidate;

            auto reducedCandidates = NaturalNumberSet(adjacencyList.length);
            auto reducedNot = NaturalNumberSet(adjacencyList.length);

            foreach (neighbourNode; adjacencyList[candidate])
            {
                if (candidates.has(neighbourNode))
                    reducedCandidates.add(neighbourNode);
                if (not.has(neighbourNode))
                    reducedNot.add(neighbourNode);
            }

            result = extendClique(clique, reducedCandidates, reducedNot, yield);

            if (result)
                return result;

            candidates.remove(candidate);
            not.add(candidate);
            --clique.length;
        }

        return result;
    }
}

/**
    Calculate a longest increasing subsequence of `sequence`. This subsequence
    is not necessarily contiguous, or unique. Given a `sequence` of `n`
    elements the algorithm uses `O(n log n)` evaluation of `pred`.

    See_Also: https://en.wikipedia.org/wiki/Longest_increasing_subsequence
*/
auto longestIncreasingSubsequence(alias pred = "a < b", Range)(Range sequence)
        if (isRandomAccessRange!Range)
{
    alias lessThan = binaryFun!pred;

    size_t[] subseqEnds;
    subseqEnds.length = sequence.length;
    size_t[] predecessors;
    predecessors.length = sequence.length;
    size_t subseqLength;

    foreach (i; 0 .. sequence.length)
    {
        // Binary search for the largest positive j < subseqLength
        // such that sequence[subseqEnds[j]] < sequence[i]
        long lo = 0;
        long hi = subseqLength - 1;
        auto pivot = sequence[i];
        assert(!lessThan(pivot, pivot), "`pred` is not anti-symmetric");

        while (lo <= hi)
        {
            auto mid = ceildiv(lo + hi, 2);

            if (lessThan(sequence[subseqEnds[mid]], pivot))
                lo = mid + 1;
            else
                hi = mid - 1;
        }

        // After searching, lo + 1 is the length of the longest prefix of
        // sequence[i]
        auto newSubseqLength = lo + 1;

        // The predecessor of sequence[i] is the last index of
        // the subsequence of length newSubseqLength - 1
        subseqEnds[lo] = i;
        if (lo > 0)
            predecessors[i] = subseqEnds[lo - 1];

        if (newSubseqLength > subseqLength)
            // If we found a subsequence longer than any we've
            // found yet, update subseqLength
            subseqLength = newSubseqLength;
    }

    auto subsequenceResult = subseqEnds[0 .. subseqLength];

    if (subseqLength > 0)
    {
        // Reconstruct the longest increasing subsequence
        // Note: reusing memory from now unused subseqEnds
        auto k = subseqEnds[subseqLength - 1];
        foreach_reverse (i; 0 .. subseqLength)
        {
            subsequenceResult[i] = k;
            k = predecessors[k];
        }
    }

    return subsequenceResult.map!(i => sequence[i]);
}

/// Example from Wikipedia
unittest
{
    import std.algorithm : equal;

    auto inputSequence = [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15];
    auto expectedOutput = [0, 2, 6, 9, 11, 15];

    assert(inputSequence.longestIncreasingSubsequence.equal(expectedOutput));
}

/// Example using a different `pred`
unittest
{
    import std.algorithm : equal;
    import std.range : retro;

    auto inputSequence = [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15];
    auto expectedOutput = [12, 10, 9, 5, 3];

    assert(inputSequence.longestIncreasingSubsequence!"a > b".equal(expectedOutput));
}

unittest
{
    import std.algorithm : equal;

    int[] inputSequence = [];
    int[] expectedOutput = [];

    assert(inputSequence.longestIncreasingSubsequence.equal(expectedOutput));
}

unittest
{
    import std.algorithm : equal;

    auto inputSequence = [1, 2, 3, 4, 5];
    auto expectedOutput = [1, 2, 3, 4, 5];

    assert(inputSequence.longestIncreasingSubsequence.equal(expectedOutput));
}

unittest
{
    import std.algorithm : equal;

    auto inputSequence = [2, 1, 3, 4, 5];
    auto expectedOutput = [1, 3, 4, 5];

    assert(inputSequence.longestIncreasingSubsequence.equal(expectedOutput));
}

unittest
{
    import std.algorithm : equal;

    auto inputSequence = [1, 2, 3, 5, 4];
    auto expectedOutput = [1, 2, 3, 4];

    assert(inputSequence.longestIncreasingSubsequence.equal(expectedOutput));
}


/**
    Compute a logarithmic index to `base` of `value` and vice versa.
    The function is piecewise linear for each interval of `base` indices.
    For interger values, the functions are mathematically equivalent to:

        logIndex(x, b) = (b - 1) ⌊log_b(x)⌋ + x / b^^⌊log_b(x)⌋

        inverseLogIndex(y, b) = (m + 1) * b^^d
        where
            m = (y - 1) mod (b - 1)
            d = ⌊(y - 1) / (b - 1)⌋
*/
size_t logIndex(size_t value, size_t base) pure nothrow @safe
{
    size_t nDigits;

    while (value >= base)
    {
        value /= base;
        ++nDigits;
    }

    return (base - 1) * nDigits + value;
}

///
unittest
{
    enum base = 10;
    auto testValues = [
        0: 0,
        1: 1,
        2: 2,
        9: 9,
        10: 10,
        11: 10,
        19: 10,
        20: 11,
        21: 11,
        29: 11,
        99: 18,
        100: 19,
        101: 19,
        199: 19,
        200: 20,
        1000: 28,
    ];

    foreach (value, result; testValues)
        assert(
            logIndex(value, base) == result,
            format!"%d != %d"(logIndex(value, base), result),
        );
}

///
unittest
{
    enum base = 16;
    auto testValues = [
        0x0000: 0,
        0x0001: 0x1,
        0x0002: 0x2,
        0x000f: 0xf,
        0x0010: 0x10,
        0x0011: 0x10,
        0x001f: 0x10,
        0x0020: 0x11,
        0x0021: 0x11,
        0x002f: 0x11,
        0x00ff: 0x1e,
        0x0100: 0x1f,
        0x0101: 0x1f,
        0x01ff: 0x1f,
        0x0200: 0x20,
        0x1000: 0x2e
    ];

    foreach (value, result; testValues)
        assert(
            logIndex(value, base) == result,
            format!"0x%x != 0x%x"(logIndex(value, base), result),
        );
}

/// ditto
size_t inverseLogIndex(size_t value, size_t base) pure nothrow @safe
{
    if (value == 0)
        return 0;

    auto nDigits = (value - 1) / (base - 1);
    auto rem = (value - 1) % (base - 1) + 1;

    return rem * base^^nDigits;
}

///
unittest
{
    enum base = 10;
    auto testValues = [
        0: 0,
        1: 1,
        2: 2,
        9: 9,
        10: 10,
        10: 10,
        11: 20,
        11: 20,
        18: 90,
        19: 100,
        20: 200,
        28: 1000,
    ];

    foreach (value, result; testValues)
        assert(
            inverseLogIndex(value, base) == result,
            format!"%d != %d"(inverseLogIndex(value, base), result),
        );
}

///
unittest
{
    enum base = 16;
    auto testValues = [
        0x00: 0x0,
        0x01: 0x1,
        0x02: 0x2,
        0x0f: 0xf,
        0x10: 0x10,
        0x10: 0x10,
        0x10: 0x10,
        0x11: 0x20,
        0x1e: 0xf0,
        0x1f: 0x100,
        0x20: 0x200,
        0x2e: 0x1000
    ];

    foreach (value, result; testValues)
        assert(
            inverseLogIndex(value, base) == result,
            format!"0x%x != 0x%x"(inverseLogIndex(value, base), result),
        );
}

unittest
{
    auto testValues = [
        0: 0,
        1: 1,
        2: 2,
        3: 3,
        4: 4,
        5: 5,
        6: 6,
        7: 7,
        8: 8,
        9: 9,
        10: 10,
        11: 20,
        12: 30,
        13: 40,
        14: 50,
        15: 60,
        16: 70,
        17: 80,
        18: 90,
        19: 100,
        20: 200,
        21: 300,
        22: 400,
        23: 500,
        24: 600,
        25: 700,
        26: 800,
        27: 900,
        28: 1000,
        29: 2000,
        30: 3000,
    ];

    foreach (value, result; testValues)
        assert(
            inverseLogIndex(value, 10) == result,
            format!"%d != %d"(inverseLogIndex(value, 10), result),
        );
}


struct Histogram(T, Flag!"logIndex" logIndex = No.logIndex)
{
    static assert(isNumeric!T, "currently only built-in numeric types are supported");

    static if (logIndex)
    {
        alias bin_size_t = size_t;
        alias indexBase = _binSize;
    }
    else
    {
        alias bin_size_t = T;
    }


    static if (isFloatingPoint!T)
    {
        enum valueInf = -T.infinity;
        enum valueSup = T.infinity;
    }
    else
    {
        enum valueInf = T.min;
        enum valueSup = T.max;
    }


    private
    {
        T _histMin;
        T _histMax;
        bin_size_t _binSize;
        enum size_t underflowIdx = 0;
        size_t overflowIdx;
        size_t[] _counts;
        size_t _totalCount;
        T _minValue;
        T _maxValue;
        T _sum;
    }


    this(T histMin, T histMax, bin_size_t binSize)
    {
        static if (isFloatingPoint!T)
            assert(
                -T.infinity < histMin && histMax < T.infinity,
                "histMin and histMax must be finite",
            );
        assert(histMin < histMax, "histMin should be less than histMax");
        assert(binSize > 0, "binSize/indexBase must be positive");

        if (histMin > histMax)
            swap(histMin, histMax);

        this._histMin = histMin;
        this._histMax = histMax;
        this._binSize = binSize;
        this.overflowIdx = rawBinIdx(histMax);
        this._counts = new size_t[overflowIdx + 1];
        this._minValue = valueSup;
        this._maxValue = valueInf;
        this._sum = 0;

        debug assert(binCoord(overflowIdx) <= histMax && histMax <= valueSup);
    }


    @property bool hasUnderflowBin() const pure nothrow @safe
    {
        static if (isFloatingPoint!T)
            return true;
        else
            return valueInf < histMin;
    }


    @property bool hasOverflowBin() const pure nothrow @safe
    {
        static if (isFloatingPoint!T)
            return true;
        else
            return histMax < valueSup;
    }


    @property inout(size_t[]) countsWithoutOutliers() inout pure nothrow @safe
    {
        size_t begin = cast(size_t) hasUnderflowBin;
        size_t end = _counts.length - 1 - cast(size_t) hasOverflowBin;

        return _counts[begin .. end];
    }


    @property size_t numUnderflows() const pure nothrow @safe
    {
        if (hasUnderflowBin)
            return _counts[underflowIdx];
        else
            return 0;
    }


    @property size_t numOverflows() const pure nothrow @safe
    {
        if (hasOverflowBin)
            return _counts[overflowIdx];
        else
            return 0;
    }


    /// Insert value into this histogram.
    void insert(T value)
    {
        ++_counts[binIdx(value)];
        ++_totalCount;
        _minValue = min(_minValue, value);
        _maxValue = max(_maxValue, value);
        _sum += value;
    }


    /// Insert a range of values into this histogram. This is equivalent to
    ///
    ///     foreach (value; values)
    ///         insert(value);
    void insert(R)(R values) if (isInputRange!R && is(ElementType!R == T))
    {
        foreach (value; values)
            insert(value);
    }


    /// Values smaller than this value are stored in the lower overflow bin.
    @property const(T) histMin() const pure nothrow @safe { return _histMin; }

    /// Values larger than this value are stored in the lower overflow bin.
    @property const(T) histMax() const pure nothrow @safe { return _histMax; }

    /// Total number of values stored in this histogram.
    @property const(size_t) totalCount() const pure nothrow @safe { return _totalCount; }

    /// Smallest value stored in this histogram. This is not subject to
    /// `histMin` and `histMax`.
    @property const(T) minValue() const pure nothrow @safe
    in (_totalCount > 0, "undefined for empty histogram")
    {
        return _minValue;
    }

    /// Largest value stored in this histogram. This is not subject to
    /// `histMin` and `histMax`.
    @property const(T) maxValue() const pure nothrow @safe
    in (_totalCount > 0, "undefined for empty histogram")
    {
        return _maxValue;
    }

    /// Sum of all values stored in this histogram. This is not subject to
    /// `histMin` and `histMax`.
    @property const(T) sum() const pure nothrow @safe
    in (_totalCount > 0, "undefined for empty histogram")
    {
        return _sum;
    }


    /// Returns a value such that roughly `percent` values in the histogram
    /// are smaller than value. The value is linearly interpolated between
    /// bin coordinates. The second form stores the bin index such that no
    /// more the `percent` of the values in the histrogram are in the bins
    /// up to `index` (inclusive).
    double percentile(
        double percent,
        Flag!"excludeOutliers" excludeOutliers = No.excludeOutliers,
    ) const pure
    {
        size_t index;

        return percentile(percent, index, excludeOutliers);
    }

    /// ditto
    double percentile(
        double percent,
        out size_t index,
        Flag!"excludeOutliers" excludeOutliers = No.excludeOutliers,
    ) const pure
    {
        assert(0.0 < percent && percent < 1.0, "percent must be between 0 and 1");

        if (totalCount == 0)
            return double.nan;

        auto threshold = excludeOutliers
            ? percent * (totalCount - (numUnderflows + numOverflows))
            : percent * totalCount;

        size_t partialSum;
        foreach (i, ref count; excludeOutliers ? countsWithoutOutliers : _counts)
        {
            if (partialSum + count >= threshold)
            {
                index = i;

                return binCoord(i) + binSize(i) * (threshold - partialSum) / count;
            }

            partialSum += count;
        }

        assert(0, "unreachable");
    }


    /// Returns the mean of the inserted values.
    @property double mean() const pure nothrow
    {
        return cast(double) sum / totalCount;
    }


    /// Iterates over the histogram bins enumerating the probability
    /// densities `density`.
    int opApply(scope int delegate(T coord, double density) yield)
    {
        int result;

        foreach (size_t idx, T coord, double density; this)
        {
            result = yield(coord, density);

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    int opApply(scope int delegate(size_t index, T coord, double density) yield)
    {
        int result;

        foreach (i, count; _counts)
        {
            result = yield(
                i,
                binCoord(i),
                cast(double) count / (totalCount * binSize(i)),
            );

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    int opApplyReverse(scope int delegate(T coord, double density) yield)
    {
        int result;

        foreach_reverse (size_t idx, T coord, double density; this)
        {
            result = yield(coord, density);

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    int opApplyReverse(scope int delegate(size_t index, T coord, double density) yield)
    {
        int result;

        foreach_reverse (i, count; _counts)
        {
            result = yield(
                i,
                binCoord(i),
                cast(double) count / (totalCount * binSize(i)),
            );

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    auto densities() const pure nothrow @safe
    {
        return _counts
            .enumerate
            .map!(enumValue => tuple!(
                "index",
                "coord",
                "density",
            )(
                enumValue.index,
                binCoord(enumValue.index),
                cast(double) enumValue.value / (totalCount * binSize(enumValue.index)),
            ));
    }


    /// Iterates over the histogram bins enumerating the counts.
    int opApply(scope int delegate(T coord, size_t count) yield)
    {
        int result;

        foreach (size_t idx, T coord, size_t count; this)
        {
            result = yield(coord, count);

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    int opApply(scope int delegate(size_t index, T coord, size_t count) yield)
    {
        int result;

        foreach (i, count; _counts)
        {
            result = yield(
                i,
                binCoord(i),
                count,
            );

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    int opApplyReverse(scope int delegate(T coord, size_t count) yield)
    {
        int result;

        foreach_reverse (size_t idx, T coord, size_t count; this)
        {
            result = yield(coord, count);

            if (result)
                break;
        }

        return result;
    }

    /// ditto
    int opApplyReverse(scope int delegate(size_t index, T coord, size_t count) yield)
    {
        int result;

        foreach_reverse (i, count; _counts)
        {
            result = yield(
                i,
                binCoord(i),
                count,
            );

            if (result)
                break;
        }

        return result;
    }


    /// Calculate the bin index corresponding to `value`.
    size_t binIdx(T value) const pure @safe
    {
        if (value < histMin)
            return underflowIdx;
        else if (histMax <= value)
            return overflowIdx;
        else
            return rawBinIdx(value);
    }

    /// ditto
    auto counts() const pure nothrow @safe
    {
        return _counts
            .enumerate
            .map!(enumValue => tuple!(
                "index",
                "coord",
                "count",
            )(
                enumValue.index,
                binCoord(enumValue.index),
                enumValue.value,
            ));
    }


    private size_t rawBinIdx(T value) const pure @safe
    {
        size_t idx;

        static if (logIndex)
        {
            static if (isFloatingPoint!T)
                idx = dalicious.math.logIndex(stdFloor(normalizedValue(value)).to!size_t, indexBase);
            else
                idx = dalicious.math.logIndex(normalizedValue(value).to!size_t, indexBase);
        }
        else
        {
            static if (isFloatingPoint!T)
                idx = stdFloor(normalizedValue(value) / binSize).to!size_t;
            else
                idx = (normalizedValue(value) / binSize).to!size_t;
        }

        return idx + cast(size_t) hasUnderflowBin;
    }


    /// Calculate the bin size at of bin `idx`.
    T binSize(size_t idx) const pure @safe
    {
        if (hasUnderflowBin && idx == underflowIdx)
            return minValue - valueInf;
        else if (hasOverflowBin && idx == overflowIdx)
            return valueSup - histMax;

        static if (logIndex)
        {
            idx -= cast(size_t) hasUnderflowBin;

            return to!T(
                dalicious.math.inverseLogIndex(idx + 1, indexBase)
                -
                dalicious.math.inverseLogIndex(idx, indexBase)
            );
        }
        else
        {
            return binSize;
        }
    }

    /// ditto
    static if (!logIndex)
        T binSize() const pure @safe
        {
            return _binSize;
        }


    /// Calculate the value corresponding to the bin index.
    T binCoord(size_t idx) const pure @safe
    {
        if (hasUnderflowBin && idx == underflowIdx)
            return valueInf;
        else if (hasOverflowBin && idx == overflowIdx)
            return histMax;

        idx -= cast(size_t) hasUnderflowBin;

        static if (logIndex)
            return primalValue(to!T(dalicious.math.inverseLogIndex(idx, indexBase)));
        else
            return primalValue(to!T(idx * binSize));
    }


    private T normalizedValue(T value) const pure nothrow @safe
    out (nValue; nValue >= 0, "normalizedValue must be non-negative")
    {
        static if (isUnsigned!T)
            assert(histMin <= value, "subtraction overflow");

        return cast(T) (value - histMin);
    }


    private T primalValue(T nValue) const pure nothrow @safe
    in (nValue >= 0, "nValue must be non-negative")
    {
        return cast(T) (nValue + histMin);
    }


    /// Returns a space-separated table of the histogram bins and header lines
    /// with `totalCount`, `minValue`, `maxValue` and `sum`. The header lines
    /// begin with a has sign (`#`) so they may be treated as comments
    /// by other programs.
    string toString() const
    {
        enum histFmt = format!(`
            # totalCount=%%d
            # minValue=%%%1$c
            # maxValue=%%%1$c
            # sum=%%%1$c
            # mean=%%g
            %%-(%%s\%%)
        `.outdent.strip.tr(`\`, "\n"))(isFloatingPoint!T ? 'g' : 'd');
        enum histLineFmt = isFloatingPoint!T
            ? "%g %g"
            : "%d %g";

        return format!histFmt(
            totalCount,
            minValue,
            maxValue,
            sum,
            mean,
            densities.map!(v => format!histLineFmt(v.coord, v.density)),
        );
    }
}

unittest
{
    auto h = logHistogram(0U, 10000U, 10U);

    with (h)
    {
        assert(binIdx(0) == 0);
        assert(binIdx(1) == 1);
        assert(binIdx(2) == 2);
        assert(binIdx(9) == 9);
        assert(binIdx(10) == 10);
        assert(binIdx(11) == 10);
        assert(binIdx(19) == 10);
        assert(binIdx(20) == 11);
        assert(binIdx(21) == 11);
        assert(binIdx(29) == 11);
        assert(binIdx(99) == 18);
        assert(binIdx(100) == 19);
        assert(binIdx(101) == 19);
        assert(binIdx(199) == 19);
        assert(binIdx(200) == 20);
        assert(binIdx(1000) == 28);

        assert(binSize(0) == 1);
        assert(binSize(1) == 1);
        assert(binSize(2) == 1);
        assert(binSize(3) == 1);
        assert(binSize(4) == 1);
        assert(binSize(5) == 1);
        assert(binSize(6) == 1);
        assert(binSize(7) == 1);
        assert(binSize(8) == 1);
        assert(binSize(9) == 1);
        assert(binSize(10) == 10);
        assert(binSize(11) == 10);
        assert(binSize(12) == 10);
        assert(binSize(13) == 10);
        assert(binSize(14) == 10);
        assert(binSize(15) == 10);
        assert(binSize(16) == 10);
        assert(binSize(17) == 10);
        assert(binSize(18) == 10);
        assert(binSize(19) == 100);
        assert(binSize(20) == 100);
        assert(binSize(21) == 100);
        assert(binSize(22) == 100);
        assert(binSize(23) == 100);
        assert(binSize(24) == 100);
        assert(binSize(25) == 100);
        assert(binSize(26) == 100);
        assert(binSize(27) == 100);
        assert(binSize(28) == 1000);
        assert(binSize(29) == 1000);
        assert(binSize(30) == 1000);

        assert(binCoord(0) == 0);
        assert(binCoord(1) == 1);
        assert(binCoord(2) == 2);
        assert(binCoord(3) == 3);
        assert(binCoord(4) == 4);
        assert(binCoord(5) == 5);
        assert(binCoord(6) == 6);
        assert(binCoord(7) == 7);
        assert(binCoord(8) == 8);
        assert(binCoord(9) == 9);
        assert(binCoord(10) == 10);
        assert(binCoord(11) == 20);
        assert(binCoord(12) == 30);
        assert(binCoord(13) == 40);
        assert(binCoord(14) == 50);
        assert(binCoord(15) == 60);
        assert(binCoord(16) == 70);
        assert(binCoord(17) == 80);
        assert(binCoord(18) == 90);
        assert(binCoord(19) == 100);
        assert(binCoord(20) == 200);
        assert(binCoord(21) == 300);
        assert(binCoord(22) == 400);
        assert(binCoord(23) == 500);
        assert(binCoord(24) == 600);
        assert(binCoord(25) == 700);
        assert(binCoord(26) == 800);
        assert(binCoord(27) == 900);
        assert(binCoord(28) == 1000);
        assert(binCoord(29) == 2000);
        assert(binCoord(30) == 3000);
    }
}


/**
    Creates a histogram of values. Additional values can be inserted into the
    histogram using the `insert` method. The second form `logHistogram`
    creates a histogram with logarithmic bin sizes.

    See_also:
        Histogram,
        dalicious.math.logIndex
*/
Histogram!T histogram(R, T = ElementType!R)(T histMin, T histMax, T binSize, R values) if (isInputRange!R)
{
    auto hist = typeof(return)(histMin, histMax, binSize);

    hist.insert(values);

    return hist;
}

/// ditto
Histogram!T histogram(T)(T histMin, T histMax, T binSize)
{
    return typeof(return)(histMin, histMax, binSize);
}

/// ditto
Histogram!(T, Yes.logIndex) logHistogram(R, T = ElementType!R)(T histMin, T histMax, size_t indexBase, R values) if (isInputRange!R)
{
    auto hist = typeof(return)(histMin, histMax, indexBase);

    hist.insert(values);

    return hist;
}

/// ditto
Histogram!(T, Yes.logIndex) logHistogram(T)(T histMin, T histMax, size_t indexBase)
{
    return typeof(return)(histMin, histMax, indexBase);
}

///
unittest
{
    // Generate a histogram of standard-normal-distributed numbers
    // with 7+2 bins from -2.0 to 2.0. The additional two bins are
    // the overflow bins.
    auto h = histogram(-2.0, 2.0, 0.5, [
        0.697108, 0.019264, -1.838430, 1.831528, -0.804880, -1.558828,
        -0.131643, -0.306090, -0.397831, 0.037725, 0.328819, -0.640064,
        0.664097, 1.156503, -0.837012, -0.969499, -1.410276, 0.501637,
        1.521720, 1.392988, -0.619393, -0.039576, 1.937708, -1.325983,
        -0.677214, 1.390584, 1.798133, -1.094093, 2.263360, -0.462949,
        1.993554, 2.243889, 1.606391, 0.153866, 1.945514, 1.007849,
        -0.663765, -0.304843, 0.617464, 0.674804, 0.038555, 1.696985,
        1.473917, -0.244211, -1.410381, 0.201184, -0.923119, -0.220677,
        0.045521, -1.966340,
    ]);

    assert(h.totalCount == 50);
    assert(approxEqual(h.minValue, -1.96634));
    assert(approxEqual(h.maxValue, 2.26336));
    assert(approxEqual(h.sum, 10.3936));
    assert(approxEqual(h.mean, 0.2079));
    assert(approxEqual(h.percentile(0.5), 0.1429));

    enum inf = double.infinity;
    auto expectedHist = [
        [-inf, 0.00],
        [-2.0, 0.12],
        [-1.5, 0.16],
        [-1.0, 0.32],
        [-0.5, 0.32],
        [ 0.0, 0.28],
        [ 0.5, 0.20],
        [ 1.0, 0.20],
        [ 1.5, 0.32],
        [ 2.0, 0.00],
    ];

    foreach (idx, coord, double density; h)
    {
        assert(approxEqual(expectedHist[idx][0], coord));
        assert(approxEqual(expectedHist[idx][1], density));
    }
}

///
unittest
{
    // Generate a histogram of geometric-distributed numbers.
    auto h = logHistogram(0U, 50U, 10U, [
        3U, 4U, 23U, 2U, 0U, 2U, 9U, 0U, 17U, 2U, 0U, 5U, 5U, 35U, 0U, 16U,
        17U, 3U, 7U, 14U, 3U, 9U, 1U, 17U, 13U, 10U, 38U, 2U, 1U, 29U, 1U,
        5U, 49U, 40U, 2U, 1U, 13U, 5U, 1U, 1U, 2U, 4U, 1U, 0U, 0U, 7U, 7U,
        34U, 3U, 2U,
    ]);

    assert(h.totalCount == 50);
    assert(h.minValue == 0);
    assert(h.maxValue == 49);
    assert(h.sum == 465);
    assert(approxEqual(h.mean, 9.3));
    assert(approxEqual(h.percentile(0.5), 4.5));

    auto expectedHist = [
        [ 0, 0.120],
        [ 1, 0.140],
        [ 2, 0.140],
        [ 3, 0.080],
        [ 4, 0.040],
        [ 5, 0.080],
        [ 6, 0.000],
        [ 7, 0.060],
        [ 8, 0.000],
        [ 9, 0.040],
        [10, 0.016],
        [20, 0.004],
        [30, 0.006],
        [40, 0.004],
        [50, 0.000],
    ];

    foreach (idx, coord, double density; h)
    {
        assert(approxEqual(expectedHist[idx][0], coord));
        assert(approxEqual(expectedHist[idx][1], density));
    }
}

unittest
{
    auto h = histogram(0U, 50U, 1U, [
        3U, 4U, 23U, 2U, 0U, 2U, 9U, 0U, 17U, 2U, 0U, 5U, 5U, 35U, 0U, 16U,
        17U, 3U, 7U, 14U, 3U, 9U, 1U, 17U, 13U, 10U, 38U, 2U, 1U, 29U, 1U,
        5U, 49U, 40U, 2U, 1U, 13U, 5U, 1U, 1U, 2U, 4U, 1U, 0U, 0U, 7U, 7U,
        34U, 3U, 2U,
    ]);

    assert(h.totalCount == 50);
    assert(h.minValue == 0);
    assert(h.maxValue == 49);
    assert(h.sum == 465);
    assert(approxEqual(h.mean, 9.3));
    assert(approxEqual(h.percentile(0.5), 4.5));

    assert(equal(h.counts.map!"a.count", [
        6, 7, 7, 4, 2, 4, 0, 3, 0, 2, 1, 0, 0, 2, 1, 0, 1, 3, 0, 0, 0, 0, 0,
        1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0,
    ]));
}


/// Encode/decode a pair of integers in a single integer. Caution: the encoded
/// value is in Θ(a * b).
Int encodePair(Int)(Int a, Int b) if (isIntegral!Int)
{
    // formula taken from https://mathforum.org/library/drmath/view/56036.html
    return ((a + b)^^2 + 3*a + b) / 2;
}

/// ditto
Int[2] decodePair(Int)(Int n) if (isIntegral!Int)
{
    import std.math : floor;

    // formulas from https://mathforum.org/library/drmath/view/56036.html
    Int c = cast(Int) floor((sqrt(8.0*n + 1.0) - 1.0)/2.0);
    Int a = n - c*(c + 1)/2;
    Int b = c - a;

    return [a, b];
}

///
unittest
{
    auto encoded = encodePair(42, 1337);

    assert(encoded == 951552);

    auto decoded = decodePair(encoded);

    assert(decoded[0] == 42);
    assert(decoded[1] == 1337);
}

unittest
{
    foreach (a; 0 .. 50)
        foreach (b; 0 .. 50)
        {
            auto n = encodePair(a, b);
            auto decoded = decodePair(n);
            auto n2 = encodePair(decoded[0], decoded[1]);

            assert(a == decoded[0]);
            assert(b == decoded[1]);
            assert(n == n2);
        }
}
