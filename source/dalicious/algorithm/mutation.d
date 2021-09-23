/**
    Some additional alogorithm functions.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.mutation;

import std.range.primitives;

/**
    Copies the content of `source` into `target` and returns the
    *filled* part of `target`. This is the counterpart of
    `std.algorithm.mutation.copy`.

    Preconditions: `target` shall have enough room to accommodate
        the entirety of `source`.
    Params:
        source = an input range
        target = an output range with slicing and length
    Returns:
        The filled part of target
*/
TargetRange bufferedIn(SourceRange, TargetRange)(SourceRange source, TargetRange target)
    if (
        isInputRange!SourceRange &&
        isOutputRange!(TargetRange, ElementType!SourceRange) &&
        hasSlicing!TargetRange && hasLength!TargetRange
    )
{
    import std.algorithm.mutation : copy;

    const bufferRest = source.copy(target);

    return target[0 .. $ - bufferRest.length];
}
