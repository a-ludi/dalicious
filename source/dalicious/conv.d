/**
    Some additional conversion functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.conv;

/**
    Return the name of a given enum value. This uses `final switch` to cause
    an assertion failure if `enumValue` is not part of `E` instead of throwing
    an exception.

    Returns: Name of enumValue.
*/
string safeEnumName(E)(E enumValue) nothrow if (is(E == enum))
{
    import std.traits : EnumMembers;

    final switch (enumValue)
    {
        static foreach (i, alias caseValue; EnumMembers!E)
        {
            case caseValue:
                return __traits(identifier, EnumMembers!E[i]);
        }
    }
}

///
unittest
{
    enum Colors
    {
        red,
        green,
        blue,
    }

    assert(Colors.red.safeEnumName == "red");
    assert(Colors.green.safeEnumName == "green");
    assert(Colors.blue.safeEnumName == "blue");
}
