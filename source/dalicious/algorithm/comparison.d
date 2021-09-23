/**
    Some additional alogorithm functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.comparison;

import std.algorithm :
    copy,
    countUntil,
    min,
    OpenRight,
    swapAt,
    uniq;
import std.conv : to;
import std.functional : binaryFun, unaryFun;
import std.traits :
    CommonType,
    isCallable,
    isDynamicArray,
    ReturnType,
    rvalueOf;
import std.typecons : Flag, No, Yes;
import std.range : enumerate;
import std.range.primitives;


/**
    Order `a` and `b` lexicographically by applying each `fun` to them. For
    unary functions compares `fun(a) < fun(b)`.
*/
template orderLexicographically(fun...)
{
    bool _orderLexicographically(T)(T a, T b)
    {
        static foreach (i, getFieldValue; fun)
        {{
            auto aValue = unaryFun!getFieldValue(a);
            auto bValue = unaryFun!getFieldValue(b);

            if (aValue != bValue)
                return aValue < bValue;
        }}

        return false;
    }

    static if (is(fun[0]))
        alias orderLexicographically = _orderLexicographically!(fun[0]);
    else
        alias orderLexicographically = _orderLexicographically;
}


/**
    Compare `a` and `b` lexicographically by applying each `fun` to them. For
    unary functions compares `fun(a) < fun(b)`.
*/
int cmpLexicographically(T, fun...)(T a, T b)
{
    static foreach (i, alias getFieldValue; fun)
    {
        {
            auto aValue = unaryFun!getFieldValue(a);
            auto bValue = unaryFun!getFieldValue(b);

            if (aValue < bValue)
            {
                return -1;
            }
            else if (aValue > bValue)
            {
                return 1;
            }
        }
    }

    return 0;
}


/// Returns one of a collection of expressions based on the value of the
/// switch expression.
template staticPredSwitch(T...)
{
    auto staticPredSwitch(E)(E switchExpression) pure nothrow
    {
        static assert (T.length > 0, "missing choices");
        enum hasDefaultClause = T.length % 2 == 1;

        static foreach (i; 0 .. T.length - 1)
        {
            static if (i % 2 == 0)
            {
                if (switchExpression == T[i])
                {
                    static if (isCallable!(T[i + 1]))
                        return T[i + 1]();
                    else
                        return T[i + 1];
                }
            }
        }

        static if (hasDefaultClause)
        {
            static if (isCallable!(T[$ - 1]))
            {
                static if (is(ReturnType!(T[$ - 1]) == void))
                {
                    T[$ - 1]();
                    assert(0);
                }
                else
                    return T[$ - 1]();
            }
            else
            {
                return T[$ - 1];
            }
        }
        else
        {
            assert(0, "none of the clauses matched in " ~ __FUNCTION__);
        }
    }
}

///
unittest
{
    alias numberName = staticPredSwitch!(
        1, "one",
        2, "two",
        3, "three",
        "many",
    );

    static assert("one" == numberName(1));
    static assert("two" == numberName(2));
    static assert("three" == numberName(3));
    static assert("many" == numberName(4));
}


/**
    Checks if both ranges are permutations of each other.

    pred must be an equivalence relation, e.i. for all inputs:

        // reflexive
        pred(a, a) == true
        // symmetric
        pred(a, b) == pred(b, a)
        // transitive
        !(pred(a, b) && pred(b, c)) || pred(a, c)

    Params:
        pred = an optional parameter to change how equality is defined
        r1 = A finite input range
        r2 = A finite random access range
        index = An index into r2 such that r2 permuted by index is a prefix of r1.
    Returns:
        `true` if all of the elements in `r1` appear the same number of times in `r2`.
        Otherwise, returns `false`.
*/
bool isPermutation(alias pred = "a == b", Flag!"nearlySorted" nearlySorted = Yes.nearlySorted, R1, R2)(R1 r1, R2 r2)
    if (
        isInputRange!R1 && !isInfinite!R1 &&
        isRandomAccessRange!R2 && !isInfinite!R2 &&
        is(CommonType!(ElementType!R1, ElementType!R2))
    )
{
    static if (hasLength!R1)
        if (r1.length != r2.length)
            return false;

    auto index = new size_t[r2.length];

    return isPermutation!(pred, nearlySorted)(r1, r2, index);
}

/// ditto
bool isPermutation(alias pred = "a == b", Flag!"nearlySorted" nearlySorted = Yes.nearlySorted, R1, R2)(R1 r1, R2 r2, size_t[] index)
if (
    isInputRange!R1 && !isInfinite!R1 &&
    isRandomAccessRange!R2 && !isInfinite!R2 &&
    is(CommonType!(ElementType!R1, ElementType!R2))
)
in (r2.length <= index.length, "index is too small")
{
    static if (hasLength!R1)
        if (r1.length != r2.length)
            return false;

    return isPermutation!(pred, nearlySorted)(r1, r2, index);
}

/// ditto
bool isPermutation(alias pred = "a == b", Flag!"nearlySorted" nearlySorted = Yes.nearlySorted, R1, R2)(R1 r1, R2 r2, ref size_t[] index)
if (
    isInputRange!R1 && !isInfinite!R1 &&
    isRandomAccessRange!R2 && !isInfinite!R2 &&
    is(CommonType!(ElementType!R1, ElementType!R2))
)
in (r2.length <= index.length, "index is too small")
{
    static if (hasLength!R1)
        if (r1.length != r2.length)
        {
            index = [];
            return false;
        }

    alias _pred = binaryFun!pred;
    const length2 = r2.length;
    index = index[0 .. length2];

    foreach (idx, ref permIndex; index)
        permIndex = idx;

    // determine longest common prefix
    size_t prefixLength = longestCommonPrefix!_pred(r1, r2[]);

    // determine permutation for the rest
    size_t i = prefixLength;
    foreach (e1; r1)
    {
        auto j = i;

        while (j < length2 && !_pred(e1, r2[index[j]]))
            ++j;
        assert(j == length2 || _pred(e1, r2[index[j]]));

        if (j == length2)
        {
            index = index[0 .. i];
            return false;
        }
        else
        {
            static if (nearlySorted)
            {
                if (j > i)
                {
                    auto tmp = index[j];
                    // shift index[i .. j] by one index
                    foreach_reverse (k; i .. j)
                        index[k + 1] = index[k];
                    index[i] = tmp;
                }
            }
            else
            {
                index.swapAt(i, j);
            }
        }

        ++i;
    }

    return true;
}

///
unittest
{
    enum r1 = [1, 2, 3, 4, 5, 6];
    enum r2 = [1, 3, 2, 4, 5, 6];

    assert(isPermutation(r1, r2));

    auto index = new size_t[r2.length];
    assert(isPermutation(r1, r2, index));
    assert(index == [0, 2, 1, 3, 4, 5]);
}

unittest
{
    import std.array : array;
    import std.random;
    import std.range : iota;

    debug (exhaustiveUnittests)
    {
        enum size_t n = 1024;
        enum size_t m = 4096;
    }
    else
    {
        enum size_t n = 64;
        enum size_t m = 32;
    }
    const size_t[] sorted = iota(n).array;
    size_t[] randomlyShuffled = iota(n).array;
    auto index = new size_t[n];

    foreach (_; 0 .. m)
    {
        randomShuffle(randomlyShuffled);

        assert(isPermutation!"a == b"(sorted, randomlyShuffled, index));
    }
}

debug (benchmark) unittest
{
    import std.algorithm : equal;
    import std.array : array;
    import std.datetime.stopwatch;
    import std.random;
    import std.range : iota;
    import std.stdio : writefln;

    enum size_t n = 64;
    const size_t[] sorted = iota(n).array;
    const size_t[] shortSwap = sorted[0 .. n/2] ~ [sorted[n/2 + 1], sorted[n/2]] ~ sorted[n/2 + 2 .. $];
    const size_t[] longSwap = sorted[1 .. $] ~ sorted[0 .. 1];
    const size_t[] randomlyShuffled = iota(n).array.randomShuffle;
    auto index = new size_t[n];
    alias eq = (size_t a, size_t b) => a == b;
    auto res = benchmark!(
        { cast(void) equal!eq(sorted, sorted); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, sorted); },
        { cast(void) isPermutation!(eq, No.nearlySorted)(sorted, sorted); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, sorted, index); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, shortSwap[]); },
        { cast(void) isPermutation!(eq, No.nearlySorted)(sorted, shortSwap[]); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, shortSwap[], index); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, longSwap[]); },
        { cast(void) isPermutation!(eq, No.nearlySorted)(sorted, longSwap[]); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, longSwap[], index); },
        { cast(void) isPermutation!(eq, Yes.nearlySorted)(sorted, randomlyShuffled[]); },
        { cast(void) isPermutation!(eq, No.nearlySorted)(sorted, randomlyShuffled[]); },
        { cast(void) isPermutation!(eq, No.nearlySorted)(sorted, randomlyShuffled[], index); },
    )(10_000);

    writefln!"-- isPermutation!(eq, nearlySorted)(sorted, r2, index):"();
    writefln!"                  equal(sorted, sorted): %s"(res[0]);
    writefln!"  r2                index  nearlySorted  took"();
    writefln!"  sorted            no     yes           %s"(res[1]);
    writefln!"  sorted            no     no            %s"(res[2]);
    writefln!"  sorted            yes    yes           %s"(res[3]);
    writefln!"  shortSwap         no     yes           %s"(res[4]);
    writefln!"  shortSwap         no     no            %s"(res[5]);
    writefln!"  shortSwap         yes    yes           %s"(res[6]);
    writefln!"  longSwap          no     yes           %s"(res[7]);
    writefln!"  longSwap          no     no            %s"(res[8]);
    writefln!"  longSwap          yes    yes           %s"(res[9]);
    writefln!"  randomlyShuffled  no     yes           %s"(res[10]);
    writefln!"  randomlyShuffled  no     no            %s"(res[11]);
    writefln!"  randomlyShuffled  yes    no            %s"(res[12]);
}


private size_t longestCommonPrefix(alias pred, R1, R2)(ref R1 r1, R2 r2)
{
    size_t prefixLength;

    static if (isRandomAccessRange!R1 && hasSlicing!R1)
    {
        const length = min(r1.length, r2.length);
        while (prefixLength < length && pred(r1[prefixLength], r2[prefixLength]))
            ++prefixLength;

        r1 = r1[prefixLength .. $];
    }
    else
    {
        while (!(r1.empty || r2.empty) && pred(r1.front, r2.front))
        {
            r1.popFront();
            r2.popFront();
            ++prefixLength;
        }
    }

    return prefixLength;
}

debug (benchmark) unittest
{
    import std.array : array;
    import std.datetime.stopwatch;
    import std.random;
    import std.range : iota;
    import std.stdio : writefln;

    struct ForwardIota
    {
        size_t n;
        size_t i;

        void popFront() pure nothrow @safe @nogc
        {
            assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

            ++i;
        }


        @property auto front() pure nothrow @safe @nogc
        {
            assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

            return i;
        }


        @property bool empty() const pure nothrow @safe @nogc
        {
            return i >= n;
        }


        @property ForwardIota save() const pure nothrow @safe @nogc
        {
            return ForwardIota(n, i);
        }
    }

    enum size_t n = 64;
    const size_t[] sortedRA = iota(n).array;
    auto sortedFR = ForwardIota(n);
    const size_t[] permuted = iota(n).array.randomShuffle;
    alias eq = (size_t a, size_t b) => a == b;
    auto res = benchmark!(
        {
            auto r1 = sortedRA[];
            cast(void) longestCommonPrefix!eq(r1, permuted[]);
        },
        {
            auto r1 = sortedFR.save;
            cast(void) longestCommonPrefix!eq(r1, permuted[]);
        },
    )(10_000);


    writefln!"random-access interface: %s"(res[0]);
    writefln!"        range interface: %s"(res[1]);
}
