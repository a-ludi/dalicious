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
import std.traits :
    isCallable,
    isDynamicArray,
    ReturnType,
    rvalueOf;
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
