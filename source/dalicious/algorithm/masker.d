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
    import std.format;

    string investigateMask(M)(M mask, lazy string err = null)
    {
        if (err == null)
            return format!"-- BEGIN\n%(%s,\n%)\n-- END"(mask);
        else
            return format!"%s:\n-- BEGIN\n%(%s,\n%)\n-- END"(err, mask);
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
)(R1 intervals, R2 boundaries = R2.init) @safe
    if (isInputRange!R1 && isInputRange!R2 && is(ElementType!R1 == ElementType!R2))
{
    alias E = ElementType!R1;
    alias _begin = unaryFun!begin;
    alias _end = unaryFun!end;

    // Trigger compilation for better debugging
    alias __debugHelper = () =>
    {
        cast(void) _begin(E.init);
        cast(void) _end(E.init);
    };
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

    () @trusted {
        chain(changeEvents, boundaryEvents).copy(eventsAcc);
    }();

    eventsAcc.data.sort();

    return MaskerImpl!(
        MEvent,
        _begin,
        _end,
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
)(R1 intervals, R2 boundaries = R2.init) @safe
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
)(R1 intervals, R2 boundaries = R2.init) @safe
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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 1, 0),
        I(1, 6, 1),
        I(6, 8, 0),
        I(8, 9, 1),
        I(9, 10, 0),
    ]), investigateMask(mask, "mask does not match"));
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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 1, Coverage.zero),
        I(1, 2, Coverage.normal),
        I(2, 5, Coverage.high),
        I(5, 6, Coverage.normal),
        I(6, 8, Coverage.zero),
        I(8, 9, Coverage.normal),
        I(9, 10, Coverage.zero),
    ]), investigateMask(mask, "mask does not match"));
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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 1, 0, 0),
        I(1, 6, 1, 4),
        I(6, 8, 0, 0),
        I(8, 9, 1, 1),
        I(9, 10, 0, 0),
    ]), investigateMask(mask, "mask does not match"));
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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 1, 0, 0),
        I(1, 6, 1, -2),
        I(6, 8, 0, 0),
        I(8, 9, 1, 5),
        I(9, 10, 0, 0),
    ]), investigateMask(mask, "mask does not match"));
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

    alias pos_t = Tuple!(size_t, size_t);
    alias beginPos = (refInt) => pos_t(refInt.contigId, refInt.begin);
    alias endPos = (refInt) => pos_t(refInt.contigId, refInt.end);

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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(
            pos_t(1, 0),
            pos_t(1, 5),
            CoverageZone.low,
        ),
        I(
            pos_t(1, 5),
            pos_t(1, 10),
            CoverageZone.ok,
        ),
        I(
            pos_t(1, 10),
            pos_t(1, 18),
            CoverageZone.high,
        ),
        I(
            pos_t(1, 18),
            pos_t(1, 20),
            CoverageZone.ok,
        ),
        I(
            pos_t(1, 20),
            pos_t(1, 30),
            CoverageZone.high,
        ),
        I(
            pos_t(2, 0),
            pos_t(2, 3),
            CoverageZone.high,
        ),
        I(
            pos_t(2, 3),
            pos_t(2, 5),
            CoverageZone.ok,
        ),
        I(
            pos_t(2, 5),
            pos_t(2, 15),
            CoverageZone.high,
        ),
        I(
            pos_t(3, 0),
            pos_t(3, 3),
            CoverageZone.low,
        ),
        I(
            pos_t(3, 3),
            pos_t(3, 12),
            CoverageZone.ok,
        ),
        I(
            pos_t(3, 12),
            pos_t(3, 15),
            CoverageZone.low,
        ),
    ]), investigateMask(mask, "mask does not match"));
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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 5, 1, 5),
        I(5, 6, 0, 0),
        I(6, 10, 1, 4),
    ]), investigateMask(mask, "mask does not match"));
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

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 10, 0),
        I(20, 30, 0),
    ]), investigateMask(mask, "mask does not match"));
}

unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!("a.begin", "a.end")([
        Interval(0, 10),
        Interval(20, 30),
    ]);

    alias I = mask.FrontType;
    assert(equal(mask, [
        I(0, 10, 1),
        I(10, 20, 0),
        I(20, 30, 1),
    ]), investigateMask(mask, "mask does not match"));
}


/// Add more intervals to masker without memory allocation for the original
/// intervals.
Masker withAdditionalIntervals(Masker, R1, R2 = R1)(
    Masker mask,
    R1 intervals,
    R2 boundaries = R2.init,
) if (
    isInputRange!R1 && isInputRange!R2 && is(ElementType!R1 == ElementType!R2) &&
    __traits(isSame, TemplateOf!Masker, MaskerImpl)
)
{
    auto changeEvents = intervals.toChangeEvents!(Masker._begin, Masker._end, No.boundaries);
    auto boundaryEvents = boundaries.toChangeEvents!(Masker._begin, Masker._end, Yes.boundaries);
    auto eventsAcc = appender!(Masker.MEvent[]);

    static if (hasLength!R1)
        eventsAcc.reserve(2 * intervals.length);
    static if (hasLength!R2)
        eventsAcc.reserve(2 * boundaries.length);

    chain(changeEvents, boundaryEvents).copy(eventsAcc);

    eventsAcc.data.sort();

    mask.addEvents(eventsAcc.data);

    return mask;
}

/// Masker can be used to compute the intersection of two masks.
unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end");

    auto mask = masker!(
        "a.begin",
        "a.end",
        level => level >= 2 ? 1 : 0,
    )(
        [
            Interval(1, 5),
            Interval(6, 7),
            Interval(9, 10),
        ],
        [Interval(0, 10)]
    );

    alias I = mask.FrontType;
    assert(equal(mask.save, [I(0, 10, 0)]));

    auto intersection1 = mask.withAdditionalIntervals([Interval(4, 7)]);
    assert(equal(
        intersection1,
        [
            I(0, 4, 0),
            I(4, 5, 1),
            I(5, 6, 0),
            I(6, 7, 1),
            I(7, 10, 0),
        ]
    ), investigateMask(mask, "mask does not match"));

    auto intersection2 = mask.withAdditionalIntervals([Interval(8, 10)]);
    assert(equal(
        intersection2,
        [
            I(0, 9, 0),
            I(9, 10, 1),
        ]
    ), investigateMask(mask, "mask does not match"));
}

unittest
{
    alias Interval = Tuple!(size_t, "begin", size_t, "end", size_t, "tag");

    auto mask = masker!(
        "a.begin",
        "a.end",
        level => level >= 2 ? 1 : 0,
        (a, b) => b.tag > 0 ? b.tag : a,
        size_t,
    )(
        [
            new Interval(1, 5, 0),
            new Interval(6, 7, 0),
            new Interval(9, 10, 0),
        ],
        [new Interval(0, 10, 0)]
    );

    alias I = mask.FrontType;
    assert(equal(mask.save, [I(0, 10, 0, 0)]), investigateMask(mask, "mask does not match"));

    auto intersection = mask.withAdditionalIntervals([
        new Interval(4, 7, 1),
        new Interval(8, 10, 2),
    ]);
    assert(equal(
        intersection,
        [
            I(0, 4, 0, 0),
            I(4, 5, 1, 1),
            I(5, 6, 0, 1),
            I(6, 7, 1, 1),
            I(7, 9, 0, 2),
            I(9, 10, 1, 2),
        ]
    ), investigateMask(intersection, "mask does not match"));
}


/// Exchange `category` function reusing the precalculated data.
Masker withCategory(alias category, Masker)(Masker mask)
    if (__traits(isSame, TemplateOf!Masker, MaskerImpl))
{
    return MaskerImpl!(
        Masker.MEvent,
        Masker._begin,
        Masker._end,
        category,
        Masker.hasRefElements,
        Masker.acc,
        Masker.acc_t,
    )(mask.originalEvents);
}


/// Exchange `acc` function reusing the precalculated data.
Masker withAcc(alias acc, acc_t, Masker)(Masker mask)
    if (__traits(isSame, TemplateOf!Masker, MaskerImpl))
{
    return MaskerImpl!(
        Masker.MEvent,
        Masker._begin,
        Masker._end,
        Masker._category,
        Masker.hasRefElements,
        acc,
        acc_t,
    )(mask.originalEvents);
}


private auto toChangeEvents(alias _begin, alias _end, Flag!"boundaries" boundaries, R)(R range) @trusted
{
    return range
        .map!(makeEvents!(_begin, _end, boundaries, ElementType!R))
        .joiner
        .filter!(event => event.type != event_t.ignore);
}


auto makeEvents(alias _begin, alias _end, Flag!"boundaries" boundaries, E)(E element) @safe
{
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
        static enum openEventType = event_t.boundaryOpen;
        static enum closeEventType = event_t.boundaryClose;
    }
    else
    {
        static enum openEventType = event_t.open;
        static enum closeEventType = event_t.close;
    }

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


private struct MaskerImpl(
    _MEvent,
    alias __begin,
    alias __end,
    alias __category,
    bool _hasRefElements,
    alias _acc,
    _acc_t,
)
{
    alias MEvent = _MEvent;
    alias _begin = __begin;
    alias _end = __end;
    alias hasRefElements = _hasRefElements;
    alias acc = _acc;
    alias acc_t = _acc_t;
    alias _category = unaryFun!__category;
    alias category_t = typeof(_category(size_t.init));
    alias pos_t = typeof(MEvent.init.pos);
    alias ElementRef = typeof(MEvent.init.elementPtr);
    enum hasAcc = !is(typeof(acc) == typeof(null));

    static struct FrontType
    {
        pos_t begin;
        pos_t end;
        category_t category;

        static if (hasAcc)
            acc_t acc;
    }

    alias Events = typeof(merge(MEvent[].init, MEvent[].init));

    MEvent[] originalEvents;
    Events events;
    private FrontType _front;
    private size_t _level;
    private bool _empty;


    this(MEvent[] events, MEvent[] additionalEvents = [])
    {
        this.originalEvents = events;
        this.events = merge(events, additionalEvents);
        popFront();
    }


    private void addEvents(MEvent[] additionalEvents)
    {
        auto originalEvents = this.originalEvents;
        this = typeof(this)(originalEvents, additionalEvents);
    }


    void popFront()
    {
        assert(!empty, "Attempting to popFront an empty " ~ typeof(this).stringof);

        if (events.empty)
            return setEmpty();

        _front.begin = currentEvent.type == event_t.boundaryOpen
            ? currentEvent.pos
            : _front.end;

        static if (hasAcc)
            _front.acc = acc_t.init;

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
        static if (hasAcc)
          auto accLevel = size_t.max;

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
                        accumulateClosedInterval(event.elementPtr);
                    break;
                case event_t.boundaryClose:
                    assert(_level == 0, "level must drop to zero at boundary end");
                    break;
                case event_t.ignore:
                    assert(0);
            }


            static if (hasAcc)
            {
                if (accLevel < size_t.max && _category(_level) == _currentCategory)
                    accLevel = size_t.max;
                else if (
                    accLevel == size_t.max &&
                    event.type == event_t.open &&
                    _category(_level) != _currentCategory
                )
                    accLevel = _level - 1;
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

        static if (hasAcc)
            accumulateStillOpenIntervals(min(accLevel, _level));

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


        private void accumulateStillOpenIntervals(size_t level)
        {
            foreach_reverse (accElementPtr; _accElements.data[0 .. level])
                accumulate(accElementPtr);
        }


        private void accumulateClosedInterval(ElementRef elementPtr)
        {
            auto elementIdx = _accElements.data.countUntil(elementPtr);
            assert(elementIdx >= 0);

            accumulate(elementPtr);

            _accElements.data.swapAt(elementIdx, _accElements.data.length - 1);
            _accElements.shrinkTo(_accElements.data.length - 1);

            assert(
                _accElements.data.length == _level,
                "number of accumulated elements must match current level",
            );
        }


        private void accumulateClosedIntervals()
        {
            foreach_reverse (accElementPtr; _accElements.data[_level .. $])
                accumulate(accElementPtr);

            _accElements.shrinkTo(_level);
        }


        private void discardClosedIntervals()
        {
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


    this(this)
    {
        this.events = this.events.save;
        static if (hasAcc)
            this._accElements = appender(this._accElements.data.dup);
    }
}
