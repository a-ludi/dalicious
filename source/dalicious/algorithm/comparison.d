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
    uniq;
import std.conv : to;
import std.functional : binaryFun, unaryFun;
import std.traits : isDynamicArray;
import std.typecons : Yes;
import std.range.primitives;


/**
    Order `a` and `b` lexicographically by applying each `fun` to them. For
    unary functions compares `fun(a) < fun(b)`.
*/
bool orderLexicographically(T, fun...)(T a, T b)
{
    static foreach (i, getFieldValue; fun)
    {
        {
            auto aValue = unaryFun!getFieldValue(a);
            auto bValue = unaryFun!getFieldValue(b);

            if (aValue != bValue)
            {
                return aValue < bValue;
            }
        }
    }

    return false;
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
        static assert (T.length % 2 == 1, "missing default clause");

        static foreach (i; 0 .. T.length - 1)
        {
            static if (i % 2 == 0)
            {
                if (switchExpression == T[i])
                    return T[i + 1];
            }
        }

        return T[$ - 1];
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
