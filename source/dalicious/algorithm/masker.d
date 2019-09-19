/**
    This module contains a genrelaized 1-D masking algorithm.

    Copyright: © 2018 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.algorithm.masker;

import std.algorithm;
import std.array;
import std.exception;
import std.functional;
import std.math;
import std.range;
import std.range.primitives;
import std.traits;
import std.typecons;


debug version(unittest)
{
    import std.stdio;

    void printMask(M)(M mask)
    {
        writefln!"-- BEGIN\n%(%s,\n%)\n-- END"(mask);
    }
}


auto masker(
    alias begin,
    alias end,
    alias category,
    alias acc,
    acc_t,
    R1,
    R2 = R1,
)(R1 intervals, R2 boundaries = R2.init)
    if (isInputRange!R1 && isInputRange!R2 && is(ElementType!R1 == ElementType!R2))
{
    alias E = ElementType!R1;
    alias _begin = unaryFun!begin;
    alias _end = unaryFun!end;

    static assert(
        is(typeof(_begin(E.init)) == typeof(_end(E.init))),
        "`begin` and `end` must have same type",
    );

    alias pos_t = typeof(_begin(E.init));

    auto changeEvents = intervals.toChangeEvents!(_begin, _end, No.boundaries);
    auto boundaryEvents = boundaries.toChangeEvents!(_begin, _end, Yes.boundaries);

    alias MEvent = ElementType!(typeof(changeEvents));

    auto eventsAcc = appender!(MEvent[]);

    static if (hasLength!R1)
        eventsAcc.reserve(2 * intervals.length);
    static if (hasLength!R2)
        eventsAcc.reserve(2 * boundaries.length);

    chain(changeEvents, boundaryEvents).copy(eventsAcc);

    eventsAcc.data.sort();

    return MaskerImpl!(
        MEvent,
        category,
        isPointer!E,
        acc,
        acc_t,
    )(eventsAcc.data);
}

/// ditto
auto masker(
    alias begin,
    alias end,
    alias category,
    R1,
    R2 = R1,
)(R1 intervals, R2 boundaries = R2.init)
    if (isInputRange!R1 && isInputRange!R2 && is(ElementType!R1 == ElementType!R2))
{
    return masker!(begin, end, category, null, void)(intervals, boundaries);
}

/// ditto
auto masker(
    alias begin,
    alias end,
    R1,
    R2 = R1,
)(R1 intervals, R2 boundaries = R2.init)
    if (isInputRange!R1 && isInputRange!R2 && is(ElementType!R1 == ElementType!R2))
{
    return masker!(begin, end, sgn)(intervals, boundaries);
}

///
unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!(
        "a.begin",
        "a.end",
    )(
        [
            Interval(1, 5),
            Interval(2, 6),
            Interval(3, 6),
            Interval(2, 4),
            Interval(8, 9),
        ],
        [Interval(0, 10)],
    );

    assert(equal(mask, [
        tuple(0, 1, 0),
        tuple(1, 6, 1),
        tuple(6, 8, 0),
        tuple(8, 9, 1),
        tuple(9, 10, 0),
    ]));
}

/// Custom `category` function:
unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    enum Coverage
    {
        zero,
        normal,
        high,
    }
    auto mask = masker!(
        "a.begin",
        "a.end",
        level => level >= 3
            ? Coverage.high
            : (level > 0
                ? Coverage.normal
                : Coverage.zero
            )
    )(
        [
            Interval(1, 5),
            Interval(2, 6),
            Interval(3, 6),
            Interval(2, 4),
            Interval(8, 9),
        ],
        [Interval(0, 10)],
    );

    assert(equal(mask, [
        tuple(0, 1, Coverage.zero),
        tuple(1, 2, Coverage.normal),
        tuple(2, 5, Coverage.high),
        tuple(5, 6, Coverage.normal),
        tuple(6, 8, Coverage.zero),
        tuple(8, 9, Coverage.normal),
        tuple(9, 10, Coverage.zero),
    ]));
}

/// The `acc` function is called once for every opening interval:
unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!(
        "a.begin",
        "a.end",
        sgn,
        "++a",
        size_t
    )(
        [
            Interval(1, 5),
            Interval(2, 6),
            Interval(3, 6),
            Interval(2, 4),
            Interval(8, 9),
        ],
        [Interval(0, 10)],
    );

    assert(equal(mask, [
        tuple(0, 1, 0, 0),
        tuple(1, 6, 1, 4),
        tuple(6, 8, 0, 0),
        tuple(8, 9, 1, 1),
        tuple(9, 10, 0, 0),
    ]));
}

/// If the intervals range has pointer type elements then the accumulator may
/// access them:payloadSum
unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end", int, "payload");

    int payloadSum(int acc, const Interval* interval)
    {
        return acc + interval.payload;
    }

    auto mask = masker!(
        "a.begin",
        "a.end",
        sgn,
        payloadSum,
        int,
    )(
        [
            new Interval(1, 5, 1),
            new Interval(2, 6, -2),
            new Interval(3, 6, 3),
            new Interval(2, 4, -4),
            new Interval(8, 9, 5),
        ],
        [new Interval(0, 10, 0)],
    );

    assert(equal(mask, [
        tuple(0, 1, 0, 0),
        tuple(1, 6, 1, -2),
        tuple(6, 8, 0, 0),
        tuple(8, 9, 1, 5),
        tuple(9, 10, 0, 0),
    ]));
}

unittest
{
    //                      c1                             c2                    c3
    //        0    5   10   15   20   25   30       0    5   10   15      0    5   10   15
    // ref:   [-----------------------------)       [--------------)      [--------------)
    // reads: .    .    .    .    .    .    .       .    .    .    .      .    .    .    .
    //        . #1 [------------) .    .    .   #12 [--) .    .    .  #23 .[--).    .    .
    //        . #2 [------------) .    .    .   #13 [--) .    .    .  #24 . [--)    .    .
    //        . #3 [--------------)    .    .   #14 [----)    .    .  #25 .  [--)   .    .
    //        .    . #4 [---------)    .    .   #15 [----)    .    .  #26 .   [--)  .    .
    //        .    . #5 [-------------------)   #16 [--------------)  #27 .    [--) .    .
    //        .    . #6 [-------------------)   #17 [--------------)  #28 .    .[--).    .
    //        .    .    #7 [----------------)   #18 [--------------)  #29 .    . [--)    .
    //        .    .    .    . #8 [---------)       .#19 [---------)  #30 .    .  [--)   .
    //        .    .    .    . #9 [---------)       .#20 [---------)  #31 .    .   [--)  .
    //        .    .    .    .#10 [---------)       .#21 [---------)  #32 .    .    [--) .
    //        .    .    .    .    #11 [-----)       .    #22 [-----)  #33 .    .    .[--).
    //        .    .    .    .    .    .    .       .    .    .    .      .    .    .    .
    // mask:  [====)    [=======) [=========)       [==) [=========)      [==) .    . [==)
    //        .    .    .    .    .    .    .       .    .    .    .      .    .    .    .
    // cov:   ^    .    .    .    .    .    .       .    .    .    .      .    .    .    .
    //        |    .    .    .    .    .    .       .    .    .    .      .    .    .    .
    //        |    .    .  +----+ .   +----+.       +-+  .   +----+.      .    .    .    .
    //        |    .    +--+####| +---+####|.       |#|  +---+####|.      .    .    .    .
    //      5 |.........|#######+-+########|.       |#+--+########|.      .    .    .    .
    //        |    .    |##################|.       |#############|.      .    .    .    .
    //        |    +----+##################|.       |#############|.      .  +-------+   .
    //        |    |#######################|.       |#############|.      . ++#######++  .
    //        |    |#######################|.       |#############|.      .++#########++ .
    //      0 +----+-----------------------+--------+-------------+--------+-----------+---->

    alias ReferenceInterval = Tuple!(
        size_t, "contigId",
        size_t, "begin",
        size_t, "end",
    );

    auto alignments = [
        ReferenceInterval(1,  5, 18), //  #1
        ReferenceInterval(1,  5, 18), //  #2
        ReferenceInterval(1,  5, 20), //  #3
        ReferenceInterval(1, 10, 20), //  #4
        ReferenceInterval(1, 10, 30), //  #5
        ReferenceInterval(1, 10, 30), //  #6
        ReferenceInterval(1, 13, 30), //  #7
        ReferenceInterval(1, 20, 30), //  #8
        ReferenceInterval(1, 20, 30), //  #9
        ReferenceInterval(1, 20, 30), // #10
        ReferenceInterval(1, 24, 30), // #11
        ReferenceInterval(2,  0,  3), // #12
        ReferenceInterval(2,  0,  3), // #13
        ReferenceInterval(2,  0,  5), // #14
        ReferenceInterval(2,  0,  5), // #15
        ReferenceInterval(2,  0, 15), // #16
        ReferenceInterval(2,  0, 15), // #17
        ReferenceInterval(2,  0, 15), // #18
        ReferenceInterval(2,  5, 15), // #19
        ReferenceInterval(2,  5, 15), // #20
        ReferenceInterval(2,  5, 15), // #21
        ReferenceInterval(2,  9, 15), // #22
        ReferenceInterval(3,  1,  4), // #23
        ReferenceInterval(3,  2,  5), // #24
        ReferenceInterval(3,  3,  6), // #25
        ReferenceInterval(3,  4,  7), // #26
        ReferenceInterval(3,  5,  8), // #27
        ReferenceInterval(3,  6,  9), // #28
        ReferenceInterval(3,  7, 10), // #29
        ReferenceInterval(3,  8, 11), // #30
        ReferenceInterval(3,  9, 12), // #31
        ReferenceInterval(3, 10, 13), // #32
        ReferenceInterval(3, 11, 14), // #33
    ];
    auto contigs = [
        ReferenceInterval(1, 0, 30),
        ReferenceInterval(2, 0, 15),
        ReferenceInterval(3, 0, 15),
    ];

    alias beginPos = (refInt) => tuple(refInt.contigId, refInt.begin);
    alias endPos = (refInt) => tuple(refInt.contigId, refInt.end);

    enum CoverageZone : ubyte
    {
        low,
        ok,
        high,
    }

    enum lowerLimit = 3;
    enum upperLimit = 5;
    alias coverageZone = (coverage) => coverage < lowerLimit
        ? CoverageZone.low
        : coverage > upperLimit
            ? CoverageZone.high
            : CoverageZone.ok;

    auto mask = masker!(
        beginPos,
        endPos,
        coverageZone,
    )(alignments, contigs);

    assert(equal(mask, [
        tuple(
            tuple(1, 0),
            tuple(1, 5),
            CoverageZone.low,
        ),
        tuple(
            tuple(1, 5),
            tuple(1, 10),
            CoverageZone.ok,
        ),
        tuple(
            tuple(1, 10),
            tuple(1, 18),
            CoverageZone.high,
        ),
        tuple(
            tuple(1, 18),
            tuple(1, 20),
            CoverageZone.ok,
        ),
        tuple(
            tuple(1, 20),
            tuple(1, 30),
            CoverageZone.high,
        ),
        // FIXME remove additional output here
        tuple(
            tuple(2, 0),
            tuple(2, 3),
            CoverageZone.high,
        ),
        tuple(
            tuple(2, 3),
            tuple(2, 5),
            CoverageZone.ok,
        ),
        tuple(
            tuple(2, 5),
            tuple(2, 15),
            CoverageZone.high,
        ),
        tuple(
            tuple(3, 0),
            tuple(3, 3),
            CoverageZone.low,
        ),
        tuple(
            tuple(3, 3),
            tuple(3, 12),
            CoverageZone.ok,
        ),
        tuple(
            tuple(3, 12),
            tuple(3, 15),
            CoverageZone.low,
        ),
    ]));
}

unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!(
        "a.begin",
        "a.end",
        sgn,
        "++a",
        size_t,
    )(
        [
            Interval(0, 5),
            Interval(0, 5),
            Interval(0, 5),
            Interval(0, 5),
            Interval(0, 5),
            Interval(6, 10),
            Interval(6, 10),
            Interval(6, 10),
            Interval(6, 10),
        ],
        [Interval(0, 10)],
    );

    assert(equal(mask, [
        tuple(0, 5, 1, 5),
        tuple(5, 6, 0, 0),
        tuple(6, 10, 1, 4),
    ]));
}

unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!("a.begin", "a.end")(
        cast(Interval[]) [],
        [
            Interval(0, 10),
            Interval(20, 30),
        ],
    );

    assert(equal(mask, [
        tuple(0, 10, 0),
        tuple(20, 30, 0),
    ]));
}

unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!("a.begin", "a.end")([
        Interval(0, 10),
        Interval(20, 30),
    ]);

    assert(equal(mask, [
        tuple(0, 10, 1),
        tuple(10, 20, 0),
        tuple(20, 30, 1),
    ]));
}


private auto toChangeEvents(alias _begin, alias _end, Flag!"boundaries" boundaries, R)(R range)
{
    alias E = ElementType!R;
    alias pos_t = typeof(_begin(E.init));

    static if (isPointer!E)
    {
        alias MEvent = MaskerEvent!(pos_t, E);
        alias _ref = (element) => element;
    }
    else
    {
        alias MEvent = MaskerEvent!(pos_t, void*);
        alias _ref = (element) => null;
    }

    static if (boundaries)
    {
        enum openEventType = event_t.boundaryOpen;
        enum closeEventType = event_t.boundaryClose;
    }
    else
    {
        enum openEventType = event_t.open;
        enum closeEventType = event_t.close;
    }


    static auto makeEvents(E)(E element)
    {
        auto begin = _begin(element);
        auto end = _end(element);

        enforce(begin <= end, "interval must not end before it begins");

        if (begin < end)
            return only(
                MEvent(begin, openEventType, _ref(element)),
                MEvent(end, closeEventType, _ref(element)),
            );
        else
            return only(MEvent(), MEvent());
    }


    return range
        .map!makeEvents
        .joiner
        .filter!(event => event.type != event_t.ignore);
}


private enum event_t : byte
{
    ignore = 0,
    boundaryOpen = 1,
    open = 2,
    close = -2,
    boundaryClose = -1,
}
static assert(event_t.init == event_t.ignore);

private alias MaskerEvent(pos_t, E) = Tuple!(
    pos_t, "pos",
    event_t, "type",
    E, "elementPtr",
);


private struct MaskerImpl(MEvent, alias category, bool hasRefElements, alias acc, acc_t)
{
    alias _category = unaryFun!category;
    alias category_t = typeof(_category(size_t.init));
    alias pos_t = typeof(MEvent.init.pos);
    alias ElementRef = typeof(MEvent.init.elementPtr);
    enum hasAcc = !is(typeof(acc) == typeof(null));

    static if (hasAcc)
    {
        alias FrontType = Tuple!(
            pos_t, "begin",
            pos_t, "end",
            category_t, "category",
            acc_t, "acc",
        );
    }
    else
    {
        alias FrontType = Tuple!(
            pos_t, "begin",
            pos_t, "end",
            category_t, "category",
        );
    }

    MEvent[] events;
    private FrontType _front;
    private size_t _level;
    private bool _empty;


    this(MEvent[] events)
    {
        this.events = events;
        popFront();
    }


    void popFront()
    {
        assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

        if (events.empty)
            return setEmpty();

        static if (hasAcc)
        {
            _front.acc = acc_t.init;
            accumulateClosedIntervals();
        }

        _front.begin = currentEvent.type == event_t.boundaryOpen
            ? currentEvent.pos
            : _front.end;
        _front.category = currentCategory;

        auto endEvent = popUntilNextCategory();
        _front.end = endEvent.pos;

        // skip empty mask intervals
        if (_front.begin == _front.end)
            popFront();
    }


    private MEvent popUntilNextCategory()
    {
        auto _currentCategory = currentCategory;
        MEvent event;

        while (!events.empty)
        {
            event = events.front;

            final switch (event.type)
            {
                case event_t.boundaryOpen:
                    assert(_level == 0, "level must be zero at boundary begin");
                    break;
                case event_t.open:
                    static if (hasAcc)
                        setAccumulate(event.elementPtr);
                    ++_level;
                    break;
                case event_t.close:
                    assert(_level > 0, "level must not drop below zero");
                    --_level;
                    static if (hasAcc)
                        accumulateClosedIntervals();
                    break;
                case event_t.boundaryClose:
                    assert(_level == 0, "level must drop to zero at boundary end");
                    break;
                case event_t.ignore:
                    assert(0);
            }

            events.popFront();

            if (
                event.type == event_t.boundaryClose ||
                (
                    _category(_level) != _currentCategory &&
                    (events.empty || event.pos != events.front.pos)
                )
            )
                break;
        }

        assert(
            !events.empty || _level == 0,
            "premature end of events",
        );

        return event;
    }


    private @property MEvent currentEvent()
    {
        return events.front;
    }


    private @property category_t currentCategory() const
    {
        return _category(_level);
    }


    static if (hasAcc)
    {
        private Appender!(ElementRef[]) _accElements;


        private void setAccumulate(ElementRef elementPtr) pure nothrow @safe
        {
            _accElements ~= elementPtr;
        }


        private void accumulateClosedIntervals()
        {
            foreach_reverse (accElementPtr; _accElements.data[_level .. $])
                accumulate(accElementPtr);

            _accElements.shrinkTo(_level);
        }


        private void accumulate(ElementRef accElementPtr)
        {
            static if (hasRefElements)
                alias callAcc = () => binaryFun!acc(_front.acc, accElementPtr);
            else
                alias callAcc = () => unaryFun!acc(_front.acc);

            if (is(ReturnType!callAcc == void))
                callAcc();
            else
                _front.acc = callAcc();
        }
    }


    private void setEmpty() pure nothrow @safe
    {
        _empty = true;
    }


    @property bool empty() const pure nothrow @safe
    {
        return _empty;
    }


    @property auto front() pure nothrow @safe
    {
        assert(!empty, "Attempting to fetch the front of an empty " ~ typeof(this).stringof);

        return _front;
    }


    @property typeof(this) save()
    {
        return this;
    }
}
