/**
    Additional traits functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.traits;

import std.meta;
import std.traits;


/// Select an alias based on a condition at compile time. Aliases can be
/// virtually anything (values, references, functions, types).
template staticIfElse(bool cond, alias ifValue, alias elseValue)
{
    static if (cond)
        alias staticIfElse = ifValue;
    else
        alias staticIfElse = elseValue;
}

unittest
{
    auto a = 42;
    auto b = "1337";

    assert(staticIfElse!(true, a, b) == 42);
    assert(staticIfElse!(false, a, b) == "1337");

    int add(int a, int b) { return a + b; }
    int sub(int a, int b) { return a - b; }

    alias fun1 = staticIfElse!(true, add, sub);
    alias fun2 = staticIfElse!(false, add, sub);

    assert(fun1(2, 3) == 5);
    assert(fun2(2, 3) == -1);
}


/// Alias of `Args` if `cond` is true; otherwise an empty `AliasSeq`.
template aliasIf(bool cond, Args...)
{
    static if (cond)
        alias aliasIf = Args;
    else
        alias aliasIf = AliasSeq!();
}

unittest
{
    int countArgs(Args...)(Args)
    {
        return Args.length;
    }

    enum answer = 42;

    assert(countArgs(aliasIf!(answer == 42, 1, 2, 3)) == 3);
    assert(countArgs(aliasIf!(answer == 1337, 1, 2, 3)) == 0);
}


/// Evaluates to true if version_ is defined.
template haveVersion(string version_)
{
    mixin(`
        version (` ~ version_ ~ `)
            enum haveVersion = true;
        else
            enum haveVersion = false;
    `);
}

unittest
{
    version (Posix)
        static assert(haveVersion!"Posix");
    else
        static assert(!haveVersion!"Posix");
}

version(unittest)
{
    version = hake_verbenaceous_unwieldily;

    static assert(haveVersion!"hake_verbenaceous_unwieldily");

    static assert(!haveVersion!"illegitimateness_bottom_mazame");
}
