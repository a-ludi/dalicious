/**
    Some additional containers.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.container;

import core.exception;


/// An array-based implementation of a ring buffer.
struct RingBuffer(T, size_t staticBufferSize = size_t.max)
{
private:

    static if (staticBufferSize < size_t.max)
       T[staticBufferSize] _buffer;
    else
       T[] _buffer;
    ptrdiff_t _frontPtr = -1;
    ptrdiff_t _backPtr;

public:

    static if (staticBufferSize == size_t.max)
    {
        @disable this();

        this(size_t bufferSize) pure nothrow @safe
        {
            this._buffer = new T[bufferSize];
        }
    }


    static if (staticBufferSize < size_t.max)
        enum bufferSize = _buffer.length;
    else
        @property size_t bufferSize() const pure nothrow @safe @nogc
        {
            return _buffer.length;
        }


    @property RingBuffer!(T, staticBufferSize) save() const pure nothrow @trusted @nogc
    {
        return cast(typeof(return)) this;
    }


    @property bool empty() const pure nothrow @safe @nogc
    {
        return _frontPtr < _backPtr || bufferSize == 0;
    }


    @property size_t length() const pure nothrow @safe @nogc
    {
        return empty ? 0 : _frontPtr - _backPtr + 1;
    }


    @property auto ref T front() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to fetch the front of an empty RingBuffer");

        return _buffer[indexOf(_frontPtr)];
    }


    @property void front(T newFront)
    {
        assert(!empty, "Attempting to assign to the front of an empty RingBuffer");

        this.front() = newFront;
    }


    @property auto ref T back() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to fetch the back of an empty RingBuffer");

        return _buffer[indexOf(_backPtr)];
    }


    @property void back(T newBack)
    {
        assert(!empty, "Attempting to assign to the back of an empty RingBuffer");

        this.back() = newBack;
    }


    void popFront() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to popFront an empty RingBuffer");

        --_frontPtr;
    }


    void popBack() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to popBack an empty RingBuffer");

        ++_backPtr;
    }


    void pushFront(T value) pure nothrow @safe @nogc
    {
        assert(bufferSize > 0, "Attempting to pushFront an zero-sized RingBuffer");

        auto wasEmpty = empty;

        ++_frontPtr;
        if (!wasEmpty && indexOf(_backPtr) == indexOf(_frontPtr))
            ++_backPtr;

        front = value;
    }

    alias put = pushFront;


    void pushBack(T value) pure nothrow @safe @nogc
    {
        assert(bufferSize > 0, "Attempting to pushBack an zero-sized RingBuffer");

        auto wasEmpty = empty;

        --_backPtr;
        if (!wasEmpty && indexOf(_backPtr) == indexOf(_frontPtr))
            --_frontPtr;
        normalizePtrs();

        back = value;
    }


    private size_t indexOf(ptrdiff_t ptr) const pure nothrow @safe @nogc
    {
        // make sure the index is positive
        return cast(size_t) ((ptr % bufferSize) + bufferSize) % bufferSize;
    }
}

unittest
{
    import std.meta;
    import std.range.primitives;

    alias Element = int;
    alias DyanmicRB = RingBuffer!Element;
    alias StaticRB = RingBuffer!(Element, 10);

    enum isDefaultConstructible(T) = is(typeof(T()));

    static assert(!isDefaultConstructible!DyanmicRB);
    static assert(isDefaultConstructible!StaticRB);

    static foreach (alias RB; AliasSeq!(DyanmicRB, StaticRB))
    {
        static assert(isInputRange!RB);
        static assert(isOutputRange!(RB, Element));
        static assert(isForwardRange!RB);
        static assert(isBidirectionalRange!RB);
        static assert(is(ElementType!RB == Element));
        static assert(hasAssignableElements!RB);
        static assert(hasLvalueElements!RB);
        static assert(hasLength!RB);
        static assert(!isInfinite!RB);
    }
}

/// Ring buffer stores the `bufferSize` most recent elements.
unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushFront(1);
    buffer.pushFront(2);
    buffer.pushFront(3);
    buffer.pushFront(4);
    buffer.pushFront(5);

    assert(buffer.front == 5);
    assert(equal(buffer, [5, 4, 3, 2, 1]));

    buffer.pushFront(6);

    assert(buffer.front == 6);
    assert(equal(buffer, [6, 5, 4, 3, 2]));
}

/// Ring buffer may have a static size.
unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!(int, 5)();

    buffer.pushFront(1);
    buffer.pushFront(2);
    buffer.pushFront(3);
    buffer.pushFront(4);
    buffer.pushFront(5);

    assert(buffer.front == 5);
    assert(equal(buffer, [5, 4, 3, 2, 1]));

    buffer.pushFront(6);

    assert(buffer.front == 6);
    assert(equal(buffer, [6, 5, 4, 3, 2]));
}

/// Elements can be removed.
unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushFront(1);
    buffer.pushFront(2);
    buffer.pushFront(3);
    buffer.pushFront(4);
    buffer.pushFront(5);

    assert(buffer.length == 5);
    assert(equal(buffer, [5, 4, 3, 2, 1]));

    buffer.popFront();
    buffer.popBack();

    assert(buffer.length == 3);
    assert(equal(buffer, [4, 3, 2]));
}

/// The buffer is double-ended.
unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushFront(1);
    buffer.pushFront(2);
    buffer.pushFront(3);
    buffer.pushFront(4);
    buffer.pushFront(5);
    buffer.pushFront(6);

    assert(buffer.front == 6);
    assert(buffer.back == 2);
    assert(equal(buffer, [6, 5, 4, 3, 2]));

    buffer.pushBack(1);

    assert(buffer.front == 5);
    assert(buffer.back == 1);
    assert(equal(buffer, [5, 4, 3, 2, 1]));
}

unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushBack(1);
    buffer.pushBack(2);
    buffer.pushBack(3);
    buffer.pushBack(4);
    buffer.pushBack(5);
    buffer.pushBack(6);

    assert(buffer.front == 2);
    assert(buffer.back == 6);
    assert(equal(buffer, [2, 3, 4, 5, 6]));
}
