/**
    Some additional alogorithm functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.searching;

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
