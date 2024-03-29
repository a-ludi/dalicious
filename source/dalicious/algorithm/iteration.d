/**
    Some additional alogorithm functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.iteration;

import dalicious.range;
import std.algorithm;
import std.conv : to;
import std.functional : binaryFun, unaryFun;
import std.meta;
import std.traits;
import std.typecons;
import std.range;
import std.range.primitives;


/**
    Slices an input array into slices of equivalent adjacent elements.
    In other languages this is often called `partitionBy`, `groupBy`
    or `sliceWhen`.

    Equivalence is defined by the predicate `pred`, which can be binary,
    which is passed to `std.functional.binaryFun`. Two range elements
    `a` and `b` are considered equivalent if `pred(a,b)` is true.

    This predicate must be an equivalence relation, that is, it must be
    reflexive (`pred(x,x)` is always true), symmetric
    (`pred(x,y) == pred(y,x)`), and transitive (`pred(x,y) && pred(y,z)`
    implies `pred(x,z)`). If this is not the case, the range returned by
    sliceBy may assert at runtime or behave erratically.

    Params:
     pred  = Predicate for determining equivalence.
     array = An array to be sliced.

    Returns: With a binary predicate, a range of slices is returned in which
    all elements in a given slice are equivalent under the given predicate.

    Notes:

    Equivalent elements separated by an intervening non-equivalent element will
    appear in separate subranges; this function only considers adjacent
    equivalence. Elements in the subranges will always appear in the same order
    they appear in the original range.
*/
auto sliceBy(alias pred, Array)(Array array) pure nothrow
        if (isDynamicArray!Array)
{
    return SliceByImpl!(pred, Array)(array);
}

///
unittest
{
    import std.algorithm.comparison : equal;

    // Grouping by particular attribute of each element:
    auto data = [
        [1, 1],
        [1, 2],
        [2, 2],
        [2, 3]
    ];

    auto r1 = data.sliceBy!((a,b) => a[0] == b[0]);
    assert(r1.equal([
        data[0 .. 2],
        data[2 .. 4]
    ]));

    auto r2 = data.sliceBy!((a,b) => a[1] == b[1]);
    assert(r2.equal([
        data[0 .. 1],
        data[1 .. 3],
        data[3 .. 4],
    ]));
}

private struct SliceByImpl(alias pred, Array)
        if (isDynamicArray!Array)
{
    private alias equivalent = binaryFun!pred;

    private Array _array;
    private size_t sliceStart;
    private size_t sliceEnd;

    this(Array array)
    {
        this._array = array;

        if (!empty)
        {
            popFront();
        }
    }

    void popFront()
    {
        assert(!empty, "Attempting to popFront an empty SliceByImpl");

        sliceStart = sliceEnd++;

        if (empty)
        {
            return;
        }

        auto refElement = _array[sliceStart];
        while (sliceEnd < _array.length && equivalent(refElement, _array[sliceEnd]))
        {
            ++sliceEnd;
        }
    }

    @property bool empty() const pure nothrow
    {
        return sliceStart >= _array.length;
    }

    @property auto front()
    {
        assert(!empty, "Attempting to fetch the front of an empty SliceByImpl");

        return _array[sliceStart .. sliceEnd];
    }

    @property SliceByImpl!(pred, Array) save() const pure nothrow
    {
        return cast(typeof(return)) this;
    }
}


/**
    Create chains of items linked by `areChainable`. This similar to `sliceBy`
    but `areChainable` does not have to be an equivalence relation.

    Params:
        areChainable  = Predicate for determining if two adjacent elements
                        should be chained.
        array         = An array to be sliced.

    Returns: With a binary predicate, a range of slices is returned in which
    predicate holds for every pair of adjacent elements in a given slice.
*/
auto chainBy(alias pred, Array)(Array array) pure nothrow
        if (isDynamicArray!Array)
{
    return ChainByImpl!(pred, Array)(array);
}

///
unittest
{
    import dalicious.math : absdiff;
    import std.algorithm.comparison : equal;

    // Chain elements that are not too far apart
    auto data = [1, 2, 3, 2, 1, 8, 5, 6, 7];

    auto r1 = data.chainBy!((a, b) => absdiff(a, b) <= 1);
    assert(r1.equal([
        data[0 .. 5],
        data[5 .. 6],
        data[6 .. 9],
    ]));
}

private struct ChainByImpl(alias _areChainable, Array)
        if (isDynamicArray!Array)
{
    private alias areChainable = binaryFun!_areChainable;

    private Array _array;
    private size_t sliceStart;
    private size_t sliceEnd;

    this(Array array)
    {
        this._array = array;

        if (!empty)
            popFront();
    }

    void popFront()
    {
        assert(!empty, "Attempting to popFront an empty ChainByImpl");

        sliceStart = sliceEnd++;

        if (empty)
            return;

        while (sliceEnd < _array.length && areChainable(_array[sliceEnd - 1], _array[sliceEnd]))
            ++sliceEnd;
    }

    @property bool empty() const pure nothrow
    {
        return sliceStart >= _array.length;
    }

    @property auto front()
    {
        assert(!empty, "Attempting to fetch the front of an empty ChainByImpl");

        return _array[sliceStart .. sliceEnd];
    }

    @property ChainByImpl!(_areChainable, Array) save() const pure nothrow
    {
        return cast(typeof(return)) this;
    }
}

/// Return the prefix of `haystack` where `pred` is not satisfied.
Array sliceUntil(alias pred = "a == b", Array, Needle)(
    Array haystack,
    Needle needle,
    OpenRight openRight = Yes.openRight,
)
        if (isDynamicArray!Array)
{
    alias predFun = binaryFun!pred;

    foreach (i, ref e; haystack)
        if (predFun(e, needle))
            return haystack[0 .. (openRight ? i : i + 1)];

    return haystack[0 .. $];
}

/// ditto
Array sliceUntil(alias pred = "a", Array)(
    Array haystack,
    OpenRight openRight = Yes.openRight,
)
        if (isDynamicArray!Array)
{
    alias predFun = unaryFun!pred;

    foreach (i, ref e; haystack)
        if (predFun(e))
            return haystack[0 .. (openRight ? i : i + 1)];

    return haystack[0 .. $];
}

///
unittest
{
    import std.typecons : No;

    int[] a = [ 1, 2, 4, 7, 7, 2, 4, 7, 3, 5];
    assert(a.sliceUntil(7) == [1, 2, 4]);
    assert(a.sliceUntil!"a == 7" == [1, 2, 4]);
    assert(a.sliceUntil(7, No.openRight) == [1, 2, 4, 7]);
}

/// Returns array filtered in-place.
auto ref Array filterInPlace(alias pred = "a", Array)(auto ref Array array) if (isDynamicArray!Array)
{
    import std.algorithm : filter;

    auto bufferRest = array.filter!pred.copy(array);

    array.length -= bufferRest.length;

    return array;
}

///
unittest
{
    alias isEven = n => n % 2 == 0;
    auto arr = [1, 2, 2, 2, 3, 3, 4];

    assert(filterInPlace!isEven(arr) == [2, 2, 2, 4]);
    // The input array gets modified.
    assert(arr == [2, 2, 2, 4]);

    // Can be called with non-lvalues
    assert(filterInPlace!isEven([1, 2, 2, 2, 3, 3, 4]) == [2, 2, 2, 4]);
}

/// Returns array `uniq`ified in-place.
auto ref Array uniqInPlace(alias pred = "a == b", Array)(auto ref Array array) if (isDynamicArray!Array)
{
    auto bufferRest = array.uniq.copy(array);

    array.length -= bufferRest.length;

    return array;
}

///
unittest
{
    auto arr = [1, 2, 2, 2, 3, 3, 4];

    assert(uniqInPlace(arr) == [1, 2, 3, 4]);
    // The input array gets modified.
    assert(arr == [1, 2, 3, 4]);

    // Can be called with non-lvalues
    assert(uniqInPlace([1, 2, 2, 2, 3, 3, 4]) == [1, 2, 3, 4]);
}

/// Replaces the first occurrence of `needle` by `replacement` in `array` if
/// present. Modifies array.
Array replaceInPlace(alias pred = "a == b", Array, E)(auto ref Array array, E needle, E replacement)
        if (isDynamicArray!Array)
{
    auto i = array.countUntil!pred(needle);

    if (i < 0)
        return array;

    array[i] = replacement;

    return array;
}

///
unittest
{
    auto arr = [1, 2, 3, 4, 2, 3];

    assert(arr.replaceInPlace(2, 7) == [1, 7, 3, 4, 2, 3]);
    // The input array gets modified.
    assert(arr == [1, 7, 3, 4, 2, 3]);
    // Replaces only the first occurrence
    assert(arr.replaceInPlace(2, 7) == [1, 7, 3, 4, 7, 3]);

    // Can be called with non-lvalues
    assert([1, 2, 3].replaceInPlace(2, 7) == [1, 7, 3]);
}

/// Get the first element in range assuming it to be non-empty.
ElementType!Range first(Range)(Range range) if (isInputRange!Range)
{
    assert(!range.empty, "must not call first on an empty range");

    return range.front;
}

///
unittest
{
    assert(first([1, 2, 3]) == 1);
    assert(first("abcd") == 'a');
}

/// Get the last element in range assuming it to be non-empty.
ElementType!Range last(Range)(Range range) if (isInputRange!Range)
{
    assert(!range.empty, "must not call last on an empty range");

    static if (isBidirectionalRange!Range)
    {
        return range.back;
    }
    else static if (hasLength!Range)
    {
        foreach (i; 0 .. range.length - 1)
            range.popFront();

        return range.front;
    }
    else static if (isForwardRange!Range)
    {
        auto checkpoint = range;

        while (!range.empty)
        {
            checkpoint = range.save;
            range.popFront();
        }

        return checkpoint.front;
    }
    else
    {
        typeof(return) lastElement;

        while (!range.empty)
        {
            lastElement = range.front;
            range.popFront();
        }

        return lastElement;
    }

}

///
unittest
{
    import std.algorithm : filter;
    import std.range : take, takeExactly;

    struct PowersOfTwo(bool shouldSave)
    {
        size_t i = 1;

        void popFront() pure nothrow
        {
            i *= 2;
        }

        @property size_t front() const pure nothrow
        {
            return i + 0;
        }

        @property bool empty() const pure nothrow
        {
            return false;
        }

        static if (shouldSave)
        {
            @property PowersOfTwo save() const pure nothrow
            {
                return cast(typeof(return)) this;
            }
        }
    }

    assert(last([1, 2, 3]) == 3);
    assert(last(PowersOfTwo!true(1).takeExactly(5)) == 16);
    assert(last(PowersOfTwo!true(1).take(5)) == 16);
    assert(last(PowersOfTwo!false(1).take(5)) == 16);
}

/**
    Find an optimal solution using backtracking.
*/
T[] backtracking(alias isFeasible, alias score, T)(
    T[] candidates,
    T[] solution = [],
)
{
    auto optimalSolution = solution;
    auto optimalScore = score(optimalSolution);

    foreach (i, candidate; candidates)
    {
        if (isFeasible(cast(const(T[])) solution ~ candidate))
        {
            auto newSolution = backtracking!(isFeasible, score)(
                candidates[0 .. i] ~ candidates[i + 1 .. $],
                solution ~ candidate,
            );
            auto newScore = score(cast(const(T[])) newSolution);

            if (newScore > optimalScore)
                optimalSolution = newSolution;
        }
    }

    return optimalSolution;
}


import std.algorithm : map;

/// Cast elements to `const(char)`.
alias charRange = map!"cast(const char) a";


///
struct Coiterator(alias cmp="a < b", Rs...)
    if (allSatisfy!(isInputRange, Rs) && Rs.length >= 2 &&
        is(CommonType!(ElementType, Rs)))
{
    alias E = CommonType!(ElementType, Rs);
    alias lowerThan = binaryFun!cmp;

    private Rs sources;
    private ptrdiff_t frontIndex;


    ///
    this(Rs sources)
    {
        this.sources = sources;
        this.frontIndex = 0;

        if (!empty)
            advanceSources();
    }


    ///
    @property bool empty()
    {
        return frontIndex < 0 || only(sources).any!"a.empty";
    }


    ///
    @property auto front()
    {
        assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

        return tupleMap!"a.front"(sources);
    }

    ///
    void popFront()
    {
        static foreach (i; 0 .. sources.length)
            popFrontSource(sources[i]);
        advanceSources();
    }


    private void advanceSources()
    {
        if (frontSourceEmpty)
        {
            frontIndex = -1;
            return;
        }

        bool allLinedUp;

        while (!allLinedUp)
        {
            // assume they are lined up and proof the contrary
            allLinedUp = true;
            foreach (i, ref source; sources)
            {
                // disregard the current frontIndex
                while (!source.empty && lowerThan(source.front, frontElement))
                    popFrontSource(source);

                if (source.empty)
                {
                    // end of co-iteration
                    frontIndex = -1;

                    return;
                }
                else if (lowerThan(frontElement, source.front))
                {
                    // source advanced beyond the sources[frontIndex]
                    frontIndex = i;
                    allLinedUp = false;
                }
            }
        }
    }


    private void popFrontSource(R)(ref R source)
    {
        version (assert)
            auto lastElement = source.front;

        source.popFront();

        version (assert)
            assert(
                source.empty || lowerThan(lastElement, source.front),
                "sources must be strictly ascending",
            );

    }


    private @property auto ref frontElement()
    {
        static foreach (i; 0 .. sources.length)
            if (i == frontIndex)
                return sources[i].front;
        assert(0, "out of bounds");
    }


    private @property bool frontSourceEmpty()
    {
        static foreach (i; 0 .. sources.length)
            if (i == frontIndex)
                return sources[i].empty;
        assert(0, "out of bounds");
    }


    ///
    static if (allSatisfy!(isForwardRange, Rs))
        @property auto save()
        {
            return typeof(this)(tupleMap!"a.save"(sources).expand);
        }
}


///
auto coiterate(alias cmp="a < b", Rs...)(Rs sources)
    if (allSatisfy!(isInputRange, Rs) && Rs.length >= 2)
{
    return Coiterator!(cmp, Rs)(sources);
}

///
unittest
{
    assert(equal(
        coiterate(
            [1, 2, 3, 4, 5],
            [   2, 3, 4, 5, 6],
            [1,    3,    5],
            [1, 2, 3, 4, 5, 6],
        ),
        [
            tuple(3, 3, 3, 3),
            tuple(5, 5, 5, 5),
        ],
    ));
}
