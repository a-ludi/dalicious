/**
    Some additional containers.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.container;

import core.exception;
import std.math;
import std.traits;
import std.typecons;


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
        this(size_t bufferSize) pure nothrow @safe
        {
            this._buffer = new T[bufferSize];
        }


        void reserve(size_t num) pure nothrow @safe
        {
            if (num <= bufferSize)
                return;

            if (empty)
            {
                _buffer.length = num;
            }
            else
            {
                auto newBuffer = new T[num];

                size_t i;
                foreach_reverse (e; this)
                    newBuffer[i++] = e;

                this._frontPtr = cast(ptrdiff_t) length - 1;
                this._backPtr = 0;
                this._buffer = newBuffer;
            }
        }
    }


    static if (staticBufferSize < size_t.max)
        enum bufferSize = _buffer.length;
    else
        @property size_t bufferSize() const pure nothrow @safe @nogc
        {
            return _buffer.length;
        }

    alias capacity = bufferSize;


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


    void clear() pure nothrow @safe @nogc
    {
        this._frontPtr = -1;
        this._backPtr = 0;
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
        normalizePtrs();
    }


    void popBack() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to popBack an empty RingBuffer");

        ++_backPtr;
        normalizePtrs();
    }


    void pushFront(T value) pure nothrow @safe @nogc
    {
        assert(bufferSize > 0, "Attempting to pushFront an zero-sized RingBuffer");

        auto wasEmpty = empty;

        ++_frontPtr;
        if (!wasEmpty && indexOf(_backPtr) == indexOf(_frontPtr))
            ++_backPtr;
        normalizePtrs();

        front = value;
    }

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

    alias put = pushBack;


    private size_t indexOf(ptrdiff_t ptr) const pure nothrow @safe @nogc
    {
        assert(0 <= ptr + 2*bufferSize);

        return cast(size_t) ((ptr + 2*bufferSize) % bufferSize);
    }


    private @property bool areNormalizedPtrs() const pure nothrow @safe @nogc
    {
        return abs(_frontPtr) <= bufferSize || abs(_backPtr) <= bufferSize;
    }


    private void normalizePtrs() pure nothrow @safe @nogc
    {
        if (areNormalizedPtrs)
            return;

        if (empty)
        {
            _frontPtr = -1;
            _backPtr = 0;
        }
        else
        {
            assert(_frontPtr >= _backPtr);
            if (0 <= _backPtr)
            {
                _frontPtr = indexOf(_frontPtr);
                _backPtr = indexOf(_backPtr);
            }
            else
            {
                _frontPtr = indexOf(_frontPtr + 2*bufferSize);
                _backPtr = indexOf(_backPtr + 2*bufferSize);
            }

            if (_frontPtr < _backPtr)
                _frontPtr += bufferSize;
        }
    }
}

unittest
{
    import std.meta;
    import std.range.primitives;

    alias Element = int;
    alias DyanmicRB = RingBuffer!Element;
    alias StaticRB = RingBuffer!(Element, 10);

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

/// The buffer can be used as an output range.
unittest
{
    import std.algorithm;
    import std.range;

    auto buffer = RingBuffer!int(32);

    iota(8).copy(&buffer);

    assert(buffer.front == 0);
    buffer.popFront();

    assert(buffer.front == 1);
    buffer.popFront();

    assert(equal(buffer, iota(2, 8)));
}

unittest
{
    import std.algorithm;
    import std.range;

    auto buffer = RingBuffer!int(32);

    auto filledBuffer = iota(8).copy(buffer);

    assert(!equal(buffer, filledBuffer));
    assert(equal(filledBuffer, iota(8)));
}

unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushBack(1); // [1]
    buffer.pushBack(2); // [1, 2]
    buffer.pushBack(3); // [1, 2, 3]
    buffer.pushBack(4); // [1, 2, 3, 4]
    buffer.pushBack(5); // [1, 2, 3, 4, 5]
    buffer.pushBack(6); // [2, 3, 4, 5, 6]

    assert(buffer.front == 2);
    assert(buffer.back == 6);
    assert(equal(buffer, [2, 3, 4, 5, 6]));
}

unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushFront(1); // [1]
    buffer.pushFront(2); // [2, 1]
    buffer.pushFront(3); // [3, 2, 1]
    buffer.pushFront(4); // [4, 3, 2, 1]
    buffer.pushFront(5); // [5, 4, 3, 2, 1]

    assert(buffer.capacity == 5);
    buffer.reserve(10);
    assert(equal(buffer, [5, 4, 3, 2, 1]));
}

unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushBack(1); // [1]
    buffer.pushBack(2); // [1, 2]
    buffer.pushBack(3); // [1, 2, 3]
    buffer.pushBack(4); // [1, 2, 3, 4]
    buffer.pushBack(5); // [1, 2, 3, 4, 5]

    assert(buffer.capacity == 5);
    assert(equal(buffer, [1, 2, 3, 4, 5]));
    buffer.reserve(10);
    assert(equal(buffer, [1, 2, 3, 4, 5]));
}

/// The size of the underlying array may be increased.
unittest
{
    import std.algorithm;

    auto buffer = RingBuffer!int(5);

    buffer.pushBack(1); // [1]
    buffer.pushBack(2); // [1, 2]
    buffer.pushBack(3); // [1, 2, 3]
    buffer.pushBack(4); // [1, 2, 3, 4]
    buffer.pushBack(5); // [1, 2, 3, 4, 5]
    // elements are no longer linear in memory
    buffer.pushBack(6); // [2, 3, 4, 5, 6]

    assert(buffer.capacity == 5);
    buffer.reserve(10);
    assert(equal(buffer, [2, 3, 4, 5, 6]));
}


/// An array-based implementation of a ring buffer.
struct BoundedStack(T, size_t staticBufferSize = size_t.max)
{
private:

    static if (staticBufferSize < size_t.max)
       T[staticBufferSize] _buffer;
    else
       T[] _buffer;
    ptrdiff_t _stackPtr = -1;

public:

    static if (staticBufferSize == size_t.max)
    {
        this(size_t bufferSize) pure nothrow @safe
        {
            this._buffer = new T[bufferSize];
        }


        this(T[] buffer) pure nothrow @safe
        {
            this._buffer = buffer;
        }


        void reserve(size_t capacity) pure nothrow @safe
        {
            if (this.capacity < capacity)
                this._buffer.length = capacity;
        }
    }


    static if (staticBufferSize < size_t.max)
        enum bufferSize = _buffer.length;
    else
        @property size_t bufferSize() const pure nothrow @safe @nogc
        {
            return _buffer.length;
        }

    alias capacity = bufferSize;


    @property T[] buffer() pure nothrow @safe @nogc
    {
        return _buffer[0 .. length];
    }


    T[] opIndex() pure nothrow @safe @nogc
    {
        return this.buffer;
    }


    @property BoundedStack!(T, staticBufferSize) save() const pure nothrow @trusted @nogc
    {
        return cast(typeof(return)) this;
    }


    @property bool empty() const pure nothrow @safe @nogc
    {
        return _stackPtr < 0 || bufferSize == 0;
    }


    @property size_t length() const pure nothrow @safe @nogc
    {
        return _stackPtr + 1;
    }


    @property auto ref T front() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to fetch the front of an empty RingBuffer");

        return _buffer[_stackPtr];
    }


    @property void front(T newFront)
    {
        assert(!empty, "Attempting to assign to the front of an empty RingBuffer");

        this.front() = newFront;
    }


    void popFront() pure nothrow @safe @nogc
    {
        assert(!empty, "Attempting to popFront an empty RingBuffer");

        --_stackPtr;
    }


    void clear() pure nothrow @safe @nogc
    {
        _stackPtr = -1;
    }


    void pushFront(T value) pure nothrow @safe @nogc
    {
        assert(capacity > 0, "Attempting to pushFront an zero-sized RingBuffer");
        assert(length < capacity, "Attempting to pushFront to a full RingBuffer");

        ++_stackPtr;
        front = value;
    }


    void pushFront(T[] values) pure nothrow @safe @nogc
    {
        assert(capacity > 0, "Attempting to pushFront an zero-sized RingBuffer");
        assert(length + values.length <= capacity, "Attempting to pushFront to a too small RingBuffer");

        _stackPtr += values.length;
        _buffer[$ - values.length .. $] = values;
    }


    alias put = pushFront;


    void opOpAssign(string op = "~=")(T value) pure nothrow @safe @nogc
    {
        pushFront(value);
    }


    void opOpAssign(string op = "~=")(T[] values) pure nothrow @safe @nogc
    {
        pushFront(values);
    }
}

unittest
{
    import std.meta;
    import std.range.primitives;

    alias Element = int;
    alias DyanmicRB = RingBuffer!Element;
    alias StaticRB = RingBuffer!(Element, 10);

    static foreach (alias RB; AliasSeq!(DyanmicRB, StaticRB))
    {
        static assert(isInputRange!RB);
        static assert(isOutputRange!(RB, Element));
        static assert(isForwardRange!RB);
        static assert(is(ElementType!RB == Element));
        static assert(hasAssignableElements!RB);
        static assert(hasLvalueElements!RB);
        static assert(hasLength!RB);
        static assert(!isInfinite!RB);
    }
}

///
unittest
{
    import std.algorithm;

    auto stack = BoundedStack!int(5);

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack.pushFront(4);
    stack.pushFront(5);

    assert(stack.front == 5);
    assert(equal(stack, [5, 4, 3, 2, 1]));
}

/// A custom buffer may be used.
unittest
{
    import std.algorithm;

    auto stack = BoundedStack!int(new int[5]);

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack.pushFront(4);
    stack.pushFront(5);

    assert(stack.front == 5);
    assert(equal(stack, [5, 4, 3, 2, 1]));
}

/// Ring buffer may have a static size.
unittest
{
    import std.algorithm;

    auto stack = BoundedStack!(int, 5)();

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack ~= 4;
    stack ~= 5;

    assert(stack.front == 5);
    assert(equal(stack, [5, 4, 3, 2, 1]));
}


/// Elements can be removed.
unittest
{
    import std.algorithm;

    auto stack = BoundedStack!int(5);

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack.pushFront(4);
    stack.pushFront(5);
    stack.popFront();
    stack.popFront();
    stack.popFront();
    stack.popFront();

    assert(stack.front == 1);
}

/// The stack can be used as an output range.
unittest
{
    import std.algorithm;
    import std.range;

    auto stack = BoundedStack!int(5);

    iota(5).copy(&stack);

    assert(equal(stack, iota(5).retro));
}

/// The stack can be resized but that may relocate the underlying buffer.
unittest
{
    import std.algorithm;

    auto stack = BoundedStack!int(5);

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack.pushFront(4);
    stack.pushFront(5);

    assert(stack.front == 5);
    assert(stack.length == stack.capacity);

    stack.reserve(10);

    stack.pushFront(6);
    stack.pushFront(7);
    stack.pushFront(8);
    stack.pushFront(9);
    stack.pushFront(10);

    assert(stack.front == 10);
}

/// The buffer may be accessed directly
unittest
{
    auto stack = BoundedStack!int(5);

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack.pushFront(4);
    stack.pushFront(5);

    assert(stack.buffer == stack[]);
    assert(stack[] == [1, 2, 3, 4, 5]);
}

unittest
{
    auto stack = BoundedStack!int(5);

    stack.pushFront(1);
    stack.pushFront(2);
    stack.pushFront(3);
    stack.pushFront(4);
    stack.pushFront(5);

    assert(stack[] == [1, 2, 3, 4, 5]);

    stack.clear();

    assert(stack[] == []);
}

static class StaticLRUCacheMiss : Exception
{
    import std.exception : basicExceptionCtors;

    ///
    mixin basicExceptionCtors;
}

struct StaticLRUCache(Key, Value, size_t cacheSize)
{
    static assert(cacheSize > 0, "zero-sized " ~ typeof(this).stringof ~ " is not allowed");

    private static struct Item
    {
        Key key;
        Value value;
        Item* next;
    }

    private Item* queue;
    private Item[cacheSize] cache;
    private size_t numCached;


    /// Returns true if key is in the cache.
    bool has(const Key key) const pure nothrow @safe @nogc
    {
        return findItem(key) !is null;
    }


    /// Returns the cached value if key is in the cache; throws otherwise.
    /// This marks the item as recently used.
    ///
    /// Throws:  StaticLRUCacheMiss if key is not in the cache.
    Value get(const Key key) pure @safe
    {
        Item* prevItemPtr;
        auto itemPtr = findItem(key, prevItemPtr);

        if (itemPtr is null)
            throw new StaticLRUCacheMiss("requested key is not in the cache");

        moveToFront(itemPtr, prevItemPtr);

        return itemPtr.value;
    }

    /// ditto
    alias opIndex = get;


    /// Returns a pointer to the cached value if key is in the cache; null
    /// otherwise. The pointer may get invalidated by updating the cache.
    /// This marks the item as recently used.
    Value* find(const Key key) pure nothrow @safe @nogc
    {
        Item* prevItemPtr;
        auto itemPtr = findItem(key, prevItemPtr);

        if (itemPtr is null)
            return null;

        moveToFront(itemPtr, prevItemPtr);

        return &itemPtr.value;
    }

    /// ditto
    const(Value)* find(const Key key) const pure nothrow @safe @nogc
    {
        auto itemPtr = findItem(key);

        if (itemPtr is null)
            return null;

        return &itemPtr.value;
    }

    /// ditto
    template opBinaryRight(string op)
    {
        static if (op == "in")
            alias opBinaryRight = find;
    }


    /// Cache value at key. Updates the value if key is already in the cache.
    /// This marks the item as recently used.
    ref Value set(Key key, Value value) return pure nothrow @safe @nogc
    {
        scope assignValue = delegate (ref Value dest) pure nothrow @safe @nogc { dest = value; };

        return set(key, assignValue);
    }


    /// ditto
    ref Value set(Func)(Key key, scope Func update) return
    if (is(typeof(update(lvalueOf!Value)) == void))
    {
        Item* prevItemPtr;
        auto itemPtr = findItem(key, prevItemPtr);

        if (itemPtr is null)
            return insertItem(key, update).value;
        else
            return updateItem(itemPtr, update, prevItemPtr).value;
    }

    /// ditto
    ref Value opIndexAssign(Value value, Key key) return pure nothrow @safe @nogc
    {
        return set(key, value);
    }

    /// ditto
    ref Value opIndexAssign(Func)(scope Func update, Key key) return
    if (is(typeof(update(lvalueOf!Value)) == void))
    {
        return set(key, update);
    }


    /// Returns the number of items in the cache.
    @property size_t length() const pure nothrow @safe @nogc
    {
        return numCached;
    }


    /// Iterate over the entries in the cache. This does not count as an
    /// access.
    int opApply(scope int delegate(ref inout(Key), ref inout(Value)) yield) inout
    {
        int result;
        inout(Item)* current = queue;

        while (current !is null)
        {
            result = yield(current.key, current.value);

            if (result)
                break;

            current = current.next;
        }

        return result;
    }

    /// ditto
    int opApply(scope int delegate(ref inout(Value)) yield) inout
    {
        int result;
        inout(Item)* current = queue;

        while (current !is null)
        {
            result = yield(current.value);

            if (result)
                break;

            current = current.next;
        }

        return result;
    }


    ref auto byKeyValue() return pure nothrow @safe @nogc
    {
        alias KeyValue = Tuple!(
            Key, "key",
            Value, "value",
        );

        static struct ByKeyValue
        {
            Item* current;

            void popFront() pure nothrow @safe
            {
                assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

                current = current.next;
            }


            @property KeyValue front() pure nothrow @safe
            {
                assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

                return KeyValue(current.key, current.value);
            }


            @property bool empty() const pure nothrow @safe
            {
                return current is null;
            }
        }

        return ByKeyValue(queue);
    }


    ref auto byKey() return pure nothrow @safe @nogc
    {
        static struct ByKey
        {
            Item* current;

            void popFront() pure nothrow @safe
            {
                assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

                current = current.next;
            }


            @property Key front() pure nothrow @safe
            {
                assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

                return current.key;
            }


            @property bool empty() const pure nothrow @safe
            {
                return current is null;
            }
        }

        return ByKey(queue);
    }


    ref auto byValue() return pure nothrow @safe @nogc
    {
        static struct ByValue
        {
            Item* current;

            void popFront() pure nothrow @safe
            {
                assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

                current = current.next;
            }


            @property Value front() pure nothrow @safe
            {
                assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

                return current.value;
            }


            @property bool empty() const pure nothrow @safe
            {
                return current is null;
            }
        }

        return ByValue(queue);
    }


    // Insert item at the beginning of the queue.
    private ref Item insertItem(Func)(ref Key key, scope Func update) return
    if (is(typeof(update(lvalueOf!Value)) == void))
    {
        if (numCached < cacheSize)
        {
            auto itemPtr = staticNewItem(key);
            moveToFront(itemPtr);
            update(itemPtr.value);

            return *itemPtr;
        }
        else
        {
            Item* secondLRUItem;
            auto lruItem = findLeastRecentlyUsedItem(secondLRUItem);

            if (lruItem !is null)
            {
                lruItem.key = key;
                update(lruItem.value);
                moveToFront(lruItem, secondLRUItem);

                return *lruItem;
            }
            else
            {
                assert(0, "unreachable");
            }
        }
    }


    private Item* staticNewItem(ref Key key) pure nothrow @safe @nogc
    out (item; item !is null)
    {
        auto itemPtr = &cache[numCached++];

        *itemPtr = Item(key);

        return itemPtr;
    }


    // Update item and move to the beginning of the queue.
    private ref Item updateItem(Func)(Item* itemPtr, scope Func update, Item* prevItemPtr) return
    if (is(typeof(update(lvalueOf!Value)) == void))
    in (itemPtr !is null)
    {
        update(itemPtr.value);
        moveToFront(itemPtr, prevItemPtr);

        return *itemPtr;
    }


    private void moveToFront(Item* item, Item* prevItem = null) pure nothrow @safe @nogc
    in (item !is null)
    {
        if (prevItem !is null)
            prevItem.next = item.next;

        item.next = queue;
        queue = item;
    }


    private Item* findLeastRecentlyUsedItem(out Item* secondLRUItem) pure nothrow @safe @nogc
    {
        Item* prevItem;

        return findBy!"a.next is null"(prevItem);
    }


    private const(Item)* findItem(const ref Key key) const pure nothrow @safe @nogc
    {
        const(Item)* prevItem;

        return findBy!"a.key == b"(prevItem, key);
    }


    private Item* findItem(const ref Key key, out Item* prevItem) pure nothrow @safe @nogc
    {
        return findBy!"a.key == b"(prevItem, key);
    }


    private inout(Item)* findBy(alias pred, Args...)(out inout(Item)* prevItem, Args args) inout
    {
        import std.functional;

        static if (Args.length == 0)
            alias _pred = unaryFun!pred;
        else static if (Args.length == 1)
            alias _pred = binaryFun!pred;
        else
            alias _pred = pred;

        inout(Item)* current = queue;
        size_t i;
        while (current !is null && i <= numCached)
        {
            if (_pred(current, args))
                return current;

            prevItem = current;
            current = current.next;
            ++i;
        }
        assert(i <= numCached, "loop detected");

        return null;
    }
}

unittest
{
    import std.algorithm.comparison : equal;

    enum cacheSize = 5;
    StaticLRUCache!(int, string, cacheSize) cache;

    // Fill the cache
    cache[1] = "Apple";
    cache[2] = "Banana";
    cache[3] = "Coconut";
    assert(cache.length == 3);
    cache[4] = "Dragonfruit";
    cache[5] = "Eggplant";
    // Cache is full; the next insertion drops the least-recently used item
    // which is (1, "Apple").
    assert(cache.length == cacheSize);
    cache[6] = "Asparagus";

    assert(equal(cache.byKeyValue, [
        tuple(6, "Asparagus"),
        tuple(5, "Eggplant"),
        tuple(4, "Dragonfruit"),
        tuple(3, "Coconut"),
        tuple(2, "Banana"),
    ]));

    // Acessing (read or write) an item marks it as recently accessed,
    // i.e. it is pushed to the front.
    cache[3] = "Carrot"; // write
    assert(cache[2] == "Banana"); // read-only
    assert(4 in cache); // read/write (returns a pointer to the value)

    assert(equal(cache.byKeyValue, [
        tuple(4, "Dragonfruit"),
        tuple(2, "Banana"),
        tuple(3, "Carrot"),
        tuple(6, "Asparagus"),
        tuple(5, "Eggplant"),
    ]));

    // An udpate can be avoided by using `has` or a `const` object.
    assert(cache.has(6));
    assert(6 in cast(const) cache);

    assert(equal(cache.byKeyValue, [
        tuple(4, "Dragonfruit"),
        tuple(2, "Banana"),
        tuple(3, "Carrot"),
        tuple(6, "Asparagus"),
        tuple(5, "Eggplant"),
    ]));
}
