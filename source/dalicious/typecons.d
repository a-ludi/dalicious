/**
    Some additional generic types.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.typecons;


/// A statically allocated array with up to `maxElements` elements.
struct BoundedArray(E, size_t maxElements_)
{
    import std.meta : allSatisfy;

    private static enum isBaseType(T) = is(T : E);


    /// An alias to the element type.
    static alias ElementType = E;


    /// The maximum number of elements this bounded array can hold.
    static enum maxElements = maxElements_;


    private E[maxElements] _elements;
    private size_t _length;


    this(V...)(V values) if (V.length > 0 && V.length <= maxElements && allSatisfy!(isBaseType, V))
    {
        this._length = V.length;
        this._elements[0 .. V.length] = [values[0 .. V.length]];
    }

    unittest
    {
        alias BArray = BoundedArray!(int, 3);

        BArray arr0;
        auto arr1 = BArray(1);
        auto arr2 = BArray(1, 2);
        auto arr3 = BArray(1, 2, 3);

        assert(arr0._length == 0);
        assert(arr0._elements == [0, 0, 0]);
        assert(arr1._length == 1);
        assert(arr1._elements == [1, 0, 0]);
        assert(arr2._length == 2);
        assert(arr2._elements == [1, 2, 0]);
        assert(arr3._length == 3);
        assert(arr3._elements == [1, 2, 3]);
    }


    ///
    @property size_t length() pure const nothrow @safe
    {
        return _length;
    }

    /// ditto
    alias opDollar = length;

    unittest
    {
        alias BArray = BoundedArray!(int, 3);

        BArray arr0;
        auto arr1 = BArray(1);
        auto arr2 = BArray(1, 2);
        auto arr3 = BArray(1, 2, 3);

        assert(arr0.length == 0);
        assert(arr1.length == 1);
        assert(arr2.length == 2);
        assert(arr3.length == 3);
    }


    ///
    inout(E[]) opIndex() inout pure nothrow @safe
    {
        return _elements[0 .. _length];
    }

    unittest
    {
        alias BArray = BoundedArray!(int, 3);

        BArray arr0;
        auto arr1 = BArray(1);
        auto arr2 = BArray(1, 2);
        auto arr3 = BArray(1, 2, 3);

        assert(arr0[] == []);
        assert(arr1[] == [1]);
        assert(arr2[] == [1, 2]);
        assert(arr3[] == [1, 2, 3]);
    }


    ///
    auto ref inout(E) opIndex(size_t idx) inout pure @safe
    {
        return this[][idx];
    }

    unittest
    {
        import core.exception : RangeError;
        import std.exception : assertThrown;

        alias BArray = BoundedArray!(int, 3);

        BArray arr0;
        auto arr1 = BArray(1);
        auto arr2 = BArray(1, 2);
        auto arr3 = BArray(1, 2, 3);

        assertThrown!RangeError(arr0[0]);
        assert(arr1[0] == 1);
        assertThrown!RangeError(arr1[1]);
        assert(arr2[0] == 1);
        assert(arr2[1] == 2);
        assertThrown!RangeError(arr2[2]);
        assert(arr3[0] == 1);
        assert(arr3[1] == 2);
        assert(arr3[2] == 3);
        assertThrown!RangeError(arr3[3]);
    }

    unittest
    {
        alias BArray = BoundedArray!(int, 3);

        auto arr = BArray(1, 2, 3);

        arr[0] = 3;
        arr[1] = 2;
        arr[2] = 1;

        assert(arr == BArray(3, 2, 1));

        arr[0] += 1;
        arr[1] += 1;
        arr[2] += 1;

        assert(arr == BArray(4, 3, 2));
    }


    ///
    typeof(this) opIndex(size_t[2] bounds) inout @safe
    {
        import std.traits : Unqual;

        alias UThis = Unqual!(typeof(this));
        alias UElements = Unqual!(typeof(this._elements[]));

        UThis slice;
        slice._length = bounds[1] - bounds[0];
        slice._elements[0 .. slice._length] = cast(UElements) this[][bounds[0] .. bounds[1]];

        return slice;
    }

    unittest
    {
        import core.exception : RangeError;
        import std.exception : assertThrown;

        alias BArray = BoundedArray!(int, 3);

        auto arr = BArray(1, 2, 3);

        assert(arr[0 .. 0] == BArray());
        assert(arr[1 .. 1] == BArray());
        assert(arr[2 .. 2] == BArray());
        assert(arr[0 .. 1] == BArray(1));
        assert(arr[1 .. 2] == BArray(2));
        assert(arr[2 .. 3] == BArray(3));
        assert(arr[0 .. 2] == BArray(1, 2));
        assert(arr[1 .. 3] == BArray(2, 3));
        assert(arr[0 .. 3] == arr);

        assertThrown!RangeError(arr[0 .. 4] == arr);
        assertThrown!RangeError(arr[3 .. 0] == arr);
    }


    size_t[2] opSlice(size_t dim)(size_t from, size_t to) const @safe if (dim == 0)
    {
        return [from, to];
    }


    ///
    typeof(this) opOpAssign(string op)(ElementType element) @safe if (op == "~")
    {
        this._elements[this.length] = element;
        this._length += 1;

        return this;
    }

    /// ditto
    typeof(this) opOpAssign(string op)(typeof(this) other) @safe if (op == "~")
    {
        auto catLength = this.length + other.length;
        this._elements[this.length .. catLength] = other[];
        this._length = catLength;

        return this;
    }

    unittest
    {
        import core.exception : RangeError;
        import std.exception :
            assertNotThrown,
            assertThrown;

        alias BArray = BoundedArray!(int, 3);

        auto arr1 = BArray(1);

        arr1 ~= 2;
        arr1 ~= 3;

        assert(arr1 == BArray(1, 2, 3));
        assertThrown!RangeError(arr1 ~= 4);

        auto arr2 = BArray(1);
        arr2 ~= BArray(2, 3);

        assert(arr2 == BArray(1, 2, 3));
        assertNotThrown!RangeError(arr2 ~= BArray());
        assertThrown!RangeError(arr2 ~= BArray(4));
    }


    ///
    typeof(this) opBinary(string op)(ElementType element) @safe if (op == "~")
    {
        typeof(this) copy = this;

        return copy ~= element;
    }

    /// ditto
    typeof(this) opBinary(string op)(typeof(this) other) @safe if (op == "~")
    {
        typeof(this) copy = this;

        return copy ~= other;
    }

    unittest
    {
        import core.exception : RangeError;
        import std.exception :
            assertNotThrown,
            assertThrown;

        alias BArray = BoundedArray!(int, 3);

        auto arr = BArray(1);

        assert(arr ~ 2 == BArray(1, 2));
        assert(arr == BArray(1));

        assert(arr ~ BArray(2, 3) == BArray(1, 2, 3));
        assert(arr == BArray(1));
        assertThrown!RangeError(arr ~ BArray(2, 3, 4));
        assertNotThrown!RangeError(BArray(2, 3, 4) ~ BArray());
    }


    /// Range primitives for a random access range.
    void popFront() pure @safe
    {
        assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

        this = this[1 .. $];
    }

    ///
    @property ref ElementType front() pure @safe
    {
        assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

        return this[0];
    }

    ///
    void popBack() pure @safe
    {
        assert(!empty, "Attempting to popBack an empty " ~ typeof(this).stringof);

        this = this[0 .. $ - 1];
    }

    ///
    @property ref ElementType back() pure @safe
    {
        assert(!empty, "Attempting to fetch the back of an empty " ~ typeof(this).stringof);

        return this[$ - 1];
    }

    ///
    @property bool empty() const pure nothrow @safe
    {
        return length == 0;
    }

    ///
    @property typeof(this) save() pure nothrow @safe
    {
        return this;
    }

    unittest
    {
        import std.algorithm : minElement;
        import std.range : dropBackOne;
        import std.range.primitives;

        alias BArray = BoundedArray!(int, 3);

        static assert(isInputRange!BArray);
        static assert(isForwardRange!BArray);
        static assert(isBidirectionalRange!BArray);
        static assert(isRandomAccessRange!BArray);
        static assert(hasMobileElements!BArray);
        static assert(hasSwappableElements!BArray);
        static assert(hasAssignableElements!BArray);
        static assert(hasLvalueElements!BArray);
        static assert(hasLength!BArray);
        static assert(hasSlicing!BArray);

        // Test popFront, front and empy
        assert(minElement(BArray(1, 2, 3)) == 1);
        // Test popBack, back and empy
        assert(dropBackOne(BArray(1, 2, 3)).back == 2);

        // Test save
        auto arr = BArray(1, 2, 3);
        arr.save.popFront();
        assert(arr.front == 1);
    }


    import vibe.data.json : Json;

    /// Convert from/to Json.
    Json toJson() const @safe
    {
        import vibe.data.json : serializeToJson;

        return serializeToJson(this[]);
    }

    /// ditto
    static typeof(this) fromJson(Json src) @safe
    {
        import std.exception : enforce;
        import std.json : JSONException;
        import std.range : enumerate;
        import vibe.data.json : deserializeJson;

        typeof(this) result;

        enforce!JSONException(
            src.length <= maxElements,
            "could not parse JSON: " ~ typeof(this).stringof ~
            " must contain <= " ~ maxElements.stringof ~ " elements",
        );

        result._length = src.length;
        foreach (i, element; src.byValue().enumerate)
            result[i] = deserializeJson!ElementType(element);

        return result;
    }

    unittest
    {
        import std.exception : assertThrown;
        import std.json : JSONException;
        import vibe.data.json :
            deserializeJson,
            serializeToJson;

        alias BArray = BoundedArray!(int, 3);

        BArray arr = BArray(1, 2, 3);

        assert(serializeToJson(arr) == serializeToJson([1, 2, 3]));
        assert(deserializeJson!BArray(serializeToJson(arr)) == arr);

        auto tooLong = serializeToJson([1, 2, 3, 4]);
        assertThrown!JSONException(deserializeJson!BArray(tooLong));
        auto mismatchedElementType = serializeToJson(["1", "2", "3", "4"]);
        assertThrown!JSONException(deserializeJson!BArray(mismatchedElementType));
    }
}

unittest
{
    import vibe.data.json :
        deserializeJson,
        serializeToJson;

    struct Complex
    {
        int foo;
    }

    alias ComplexArray = BoundedArray!(Complex, 3);

    auto arr = ComplexArray(Complex(1), Complex(2), Complex(3));

    assert(deserializeJson!ComplexArray(serializeToJson(arr)) == arr);
}

unittest
{
    BoundedArray!(int, 3) triggerUnitTests;
}
