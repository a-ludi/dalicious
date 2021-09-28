/**
    Central logging facility for dalicious.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.log;

import core.thread;
import dalicious.traits;
import std.algorithm;
import std.array;
import std.datetime.stopwatch;
import std.format;
import std.process;
import std.range;
import std.stdio;
import std.traits;
import std.typecons;

private
{
    __gshared LogLevel minLevel = LogLevel.info;
    __gshared File logFile;
}


static this()
{
    synchronized
        if (!logFile.isOpen)
            setLogFile(stderr);
}


/// Sets the log file.
void setLogFile(File logFile)
{
    synchronized
        .logFile = logFile;
}


/// Get the log file.
File getLogFile() nothrow
{
    return logFile;
}


/// Sets the minimum log level to be printed.
void setLogLevel(LogLevel level) nothrow
{
    synchronized
        minLevel = level;
}

LogLevel getLogLevel() nothrow @nogc
{
    return minLevel;
}

bool shouldLog(LogLevel level) nothrow @nogc
{
    return level >= minLevel;
}

/**
    Logs a message in JSON format. If the `name` part is `null` the field
    will not be included into the Json.

    Params:
        args = pairs of `name` (`string`) and `value`
*/
void logJsonDebug(T...)(lazy T args) nothrow
{
    logJson(LogLevel.debug_, args);
}
/// ditto
void logJsonDiagnostic(T...)(lazy T args) nothrow
{
    logJson(LogLevel.diagnostic, args);
}
/// ditto
void logJsonInfo(T...)(lazy T args) nothrow
{
    logJson(LogLevel.info, args);
}
/// ditto
void logJsonWarn(T...)(lazy T args) nothrow
{
    logJson(LogLevel.warn, args);
}
/// ditto
void logJsonError(T...)(lazy T args) nothrow
{
    logJson(LogLevel.error, args);
}

/// ditto
void logJson(T...)(LogLevel level, lazy T args) nothrow
{
    import dalicious.range : Chunks, chunks;
    import std.datetime.systime : Clock;
    import std.traits : isSomeString;
    import vibe.data.json : Json, serializeToJson;

    enum threadKey = "thread";
    enum timestampKey = "timestamp";

    if (level < minLevel)
        return;

    try
    {
        Json json = Json.emptyObject;

        static foreach (KeyValuePair; Chunks!(2, T))
        {
            static assert(isSomeString!(KeyValuePair.chunks[0]), "missing name");
        }

        json[timestampKey] = Clock.currStdTime;
        json[threadKey] = thisThreadID;

        foreach (keyValuePair; args.chunks!2)
            if (keyValuePair[0] !is null)
                json[keyValuePair[0]] = serializeToJson(keyValuePair[1]);

        return log(level, json.to!string);
    }
    catch (Exception e)
    {
        // this is bad but what can we do..
        debug assert(false, e.msg);
    }
}

///
unittest
{
    import std.stdio : File, stderr;
    import vibe.data.json : Json, parseJsonString;

    auto logFile = File.tmpfile();
    setLogFile(logFile);
    scope (exit)
        setLogFile(stderr);

    logJsonError("error", "mysterious observation", "secret", 42);

    logFile.rewind();
    auto observed = parseJsonString(logFile.readln);

    assert(observed["thread"].type == Json.Type.int_);
    assert(observed["timestamp"].type == Json.Type.int_);
    assert(observed["error"] == "mysterious observation");
    assert(observed["secret"] == 42);
}

/**
    Logs a message.
    Params:
        level = The log level for the logged message
        fmt = See http://dlang.org/phobos/std_format.html#format-string
*/
void logDebug(T...)(string fmt, lazy T args) nothrow
{
    log(LogLevel.debug_, fmt, args);
}
/// ditto
void logDiagnostic(T...)(string fmt, lazy T args) nothrow
{
    log(LogLevel.diagnostic, fmt, args);
}
/// ditto
void logInfo(T...)(string fmt, lazy T args) nothrow
{
    log(LogLevel.info, fmt, args);
}
/// ditto
void logWarn(T...)(string fmt, lazy T args) nothrow
{
    log(LogLevel.warn, fmt, args);
}
/// ditto
void logError(T...)(string fmt, lazy T args) nothrow
{
    log(LogLevel.error, fmt, args);
}

/// ditto
void log(T...)(LogLevel level, string fmt, lazy T args) nothrow
{
    if (level < minLevel)
        return;

    try
    {
        auto txt = appender!string();
        txt.reserve(256);
        static if (args.length > 0)
        {
            formattedWrite(txt, fmt, args);
        }
        else
        {
            txt ~= fmt;
        }

        if (level >= minLevel)
        {
            synchronized
                if (logFile.isOpen)
                {
                    logFile.writeln(txt.data);
                    logFile.flush();
                }
        }
    }
    catch (Exception e)
    {
        // this is bad but what can we do..
        debug assert(false, e.msg);
    }
}

/// Specifies the log level for a particular log message.
enum LogLevel
{
    debug_,
    diagnostic,
    info,
    warn,
    error,
    fatal,
    none
}

struct ExecutionTracer(LogLevel logLevel = LogLevel.diagnostic)
{
    import std.datetime.stopwatch : StopWatch;
    import std.typecons : Yes;

    string functionName;
    StopWatch timer;

    this(int dummy, string fnName = __FUNCTION__) nothrow @safe
    {
        this.functionName = fnName;

        () @trusted { logJson(
            logLevel,
            `state`, `enter`,
            `function`, this.functionName,
        ); }();

        this.timer = StopWatch(Yes.autoStart);
    }

    ~this() nothrow @safe
    {
        timer.stop();

        () @trusted { logJson(
            logLevel,
            `state`, `exit`,
            `function`, functionName,
            `timeElapsedSecs`, timer.peek().total!`hnsecs` * 100e-9,
        ); }();
    }
}

string traceExecution(LogLevel logLevel = LogLevel.diagnostic)()
{
    import std.conv : to;
    import std.string : replace;
    import std.traits : moduleName;

    return q"{
        static import $thisModule;

        scope __executionTracer = $thisModule.ExecutionTracer!($logLevel)(0);
    }"
        .replace("$thisModule", moduleName!LogLevel)
        .replace("$logLevel", "LogLevel." ~ logLevel.to!string);
}


unittest
{
    import std.regex : ctRegex, matchFirst;
    import std.stdio : File, stderr;
    import vibe.data.json : Json, parseJsonString;

    auto logFile = File.tmpfile();
    setLogFile(logFile);
    scope (exit)
        setLogFile(stderr);

    void doSomething()
    {
        mixin(traceExecution!(LogLevel.error));

        import core.thread : Thread;
        import core.time : dur;

        Thread.getThis.sleep(dur!"hnsecs"(50));
    }

    doSomething();
    logFile.rewind();

    enum functionFQN = ctRegex!`dalicious\.log\.__unittest_L[0-9]+_C[0-9]+\.doSomething`;
    auto observed1 = parseJsonString(logFile.readln);
    auto observed2 = parseJsonString(logFile.readln);

    assert(observed1["thread"].type == Json.Type.int_);
    assert(observed1["timestamp"].type == Json.Type.int_);
    assert(observed1["state"] == "enter");
    assert(matchFirst(observed1["function"].to!string, functionFQN));

    assert(observed2["thread"].type == Json.Type.int_);
    assert(observed2["timestamp"].type == Json.Type.int_);
    assert(observed2["state"] == "exit");
    assert(matchFirst(observed2["function"].to!string, functionFQN));
}


/// Create a new todo. A todo list will be generated on end of compilation.
debug enum todo(string task, string file = __FILE__, size_t line = __LINE__) =
    "[TODO] " ~ task ~ " at " ~ file ~ ":" ~ line.stringof;


/// Track progress over time on text-based output device.
class ProgressMeter
{
    alias UnitSpec = Tuple!(size_t, "multiplier", char, "name");


    /// Display unit for the progress meter.
    enum Unit : UnitSpec
    {
        /// Automitcally select apropriate unit.α
        ///
        /// See_also: selectUnitFor
        auto_ = UnitSpec(0, '\0'),

        /// Display raw counts.
        one = UnitSpec(1, ' '),

        /// Display counts in units of `10^3`.
        kilo = UnitSpec(10^^3, 'k'),

        /// Display counts in units of `10^6`.
        mega = UnitSpec(10^^6, 'M'),

        /// Display counts in units of `10^9`.
        giga = UnitSpec(10^^9, 'G'),

        /// Display counts in units of `10^12`.
        peta = UnitSpec(10^^12, 'P'),

        /// Alias for `one`.
        min = one,

        /// Alias for `peta`.
        max = peta,
    }


    /// Display format for the progress meter.
    enum Format : ubyte
    {
        /// Print an self-updating status line. This is meant for display on a
        /// terminal. For output into a file `json` should be preferred.
        human,
        /// Print a series of JSON objects. This is meant for output into a
        /// file. For output to a terminal `human` should be preferred.
        ///
        /// Example output:
        ///
        /// ```json
        /// {"ticks":41,"elapsedSecs":20.000,"ticksPerSec":2.050,"etaSecs":88.15}
        /// {"ticks":42,"elapsedSecs":21.000,"ticksPerSec":2.000,"etaSecs":84.00}
        /// {"ticks":43,"elapsedSecs":22.000,"ticksPerSec":1.955,"etaSecs":80.16}
        /// ```
        json,
    }


    /// Set this to the total number of ticks if known.
    size_t totalTicks;

    /// Print a progress update at most this frequently. Progress lines are
    /// only ever printed on `start`, `stop`, `tick` and `updateNumTicks`.
    size_t printEveryMsecs = 500;

    /// Select output format.
    ///
    /// See_also: Format
    Format format;

    /// Suppress all output but still keep track of things.
    Flag!"silent" silent;

    /// Display unit for format `human`.
    Unit unit;

    /// Number of digits of decimal fractions.
    size_t precision = 3;

    /// Current number of ticks. Automatically updates the status when the
    /// timer is running.
    ///
    /// See_also: updateNumTicks
    @property size_t numTicks() const pure nothrow @safe @nogc
    {
        return _numTicks;
    }

    /// ditto
    @property void numTicks(size_t value)
    {
        updateNumTicks(value);
    }

    protected size_t _numTicks;
    protected File _output;
    protected bool hasOutput;
    protected StopWatch timer;
    protected StopWatch lastPrint;


    this(
        size_t totalTicks = 0,
        size_t printEveryMsecs = 500,
        Format format = Format.human,
        Flag!"silent" silent = No.silent,
        Unit unit = Unit.auto_,
        size_t precision = 3,
    ) pure nothrow @safe @nogc
    {
        this.totalTicks = totalTicks;
        this.printEveryMsecs = printEveryMsecs;
        this.format = format;
        this.silent = silent;
        this.unit = unit;
        this.precision = precision;
    }


    ~this()
    {
        if(isRunning())
            stop();
    }


    /// Get/set the output file.
    @property void output(File output)
    in (!isRunning)
    {
        hasOutput = true;
        _output = output;
    }


    /// ditto
    @property auto ref File output()
    {
        if (!hasOutput)
            output = stderr;

        return _output;
    }


    /// Start the timer. Print the first status line if format is `human`.
    void start()
    in (!isRunning, "Attempting to start() a running ProgressMeter.")
    {
        _numTicks = 0;
        if (!silent)
        {
            lastPrint.reset();
            lastPrint.start();
            printProgressLine(LineLocation.first);
        }
        timer.reset();
        timer.start();
    }


    /// Advance the number of ticks. Prints a status line when at least
    /// `printEveryMsecs` milliseconds have passed since the last print.
    void tick(size_t newTicks = 1)
    in (isRunning, "Attempting to tick() a stopped ProgressMeter.")
    {
        updateNumTicks(numTicks + newTicks);
    }


    /// Set the number of ticks. Prints a status line when at least
    /// `printEveryMsecs` milliseconds have passed since the last print.
    void updateNumTicks(size_t numTicks)
    in (isRunning, "Attempting to update numTicks of a stopped ProgressMeter.")
    {
        this._numTicks = numTicks;

        if (!silent && lastPrint.peek.total!"msecs" >= printEveryMsecs)
            printProgressLine(LineLocation.middle);
    }


    /// Stop the timer. Prints a final status line.
    void stop()
    in (isRunning, "Attempting to stop() a stopped ProgressMeter.")
    {
        timer.stop();

        if (!silent)
            printProgressLine(LineLocation.last);
    }


    /// Returns true if the timer is running.
    @property bool isRunning() const pure nothrow @safe @nogc
    {
        return timer.running();
    }


    ///
    static enum isValidTimeUnit(string timeUnit) = is(typeof(timer.peek.total!timeUnit));
    static assert(isValidTimeUnit!"msecs");


    ///
    @property auto elapsed(string timeUnit)() const nothrow @safe if (isValidTimeUnit!timeUnit)
    {
        return timer.peek.total!timeUnit;
    }


    ///
    @property auto elapsedSecs() const nothrow @safe
    {
        try
        {
            return precision.predSwitch!"a <= b"(
                0, elapsed!"seconds",
                3, elapsed!"msecs" * 1e-3,
                6, elapsed!"usecs" * 1e-6,
                elapsed!"nsecs" * 1e-9,
            );
        }
        catch (Exception)
        {
            assert(0);
        }
    }


    ///
    @property auto ticksPerSec() const nothrow @safe
    {
        return cast(double) numTicks / elapsedSecs;
    }


    /// Returns true when `etaSecs` is defined.
    @property auto hasETA() const nothrow @safe
    {
        return totalTicks > 0 && numTicks > 0;
    }

    /// ditto
    alias hasEstimatedTimeOfArrival = hasETA;


    /// Compute estimated time of arrival (ETA) with a simple linear model.
    ///
    /// ```d
    /// const etaSecs = (totalTicks - numTicks)/ticksPerSec;
    /// ```
    ///
    /// Returns:  Estimated time of arrival id `hasETA`; otherwise `double.infinity`.
    @property double etaSecs() const nothrow @safe
    {
        return hasETA?  (totalTicks - numTicks)/ticksPerSec : double.infinity;
    }

    /// ditto
    alias estimatedTimeOfArrivalSecs = etaSecs;


    /// Select unit such that number can be displayed with three leading
    /// decimal digits.
    static Unit selectUnitFor(size_t number) pure nothrow @safe
    {
        foreach (unit; EnumMembers!Unit)
            if (unit.multiplier > 0 && number / unit.multiplier < 1000)
                return unit;
        return Unit.max;
    }


protected:


    enum LineLocation : ubyte
    {
        first,
        middle,
        last,
    }


    void printProgressLine(LineLocation lineLocation)
    {
        final switch (format)
        {
            case Format.human:
                printHumanProgressLine(lineLocation);
                break;
            case Format.json:
                printJsonProgressLine(lineLocation);
                break;
        }

        lastPrint.reset();
    }


    void printHumanProgressLine(LineLocation lineLocation)
    {
        enum progressFormat = "\rrecords: %04.*f%c  elapsed: %04.*f sec  rate: %04.*f records/sec";
        enum progressFormatWithTotal = "\rrecords: %04.*f/%04.*f%c (%04.2f%%) eta: %04.*f sec  elapsed: %04.*f sec  rate: %04.*f records/sec";

        auto unit = this.unit == Unit.auto_
            ? selectUnitFor(max(numTicks, totalTicks))
            : this.unit;

        if (!hasETA)
            output.writef!progressFormat(
                precision,
                cast(double) numTicks / unit.multiplier,
                unit.name,
                precision,
                elapsedSecs,
                precision,
                cast(double) numTicks / elapsedSecs,
            );
        else
            output.writef!progressFormatWithTotal(
                precision,
                cast(double) numTicks / unit.multiplier,
                precision,
                cast(double) totalTicks / unit.multiplier,
                unit.name,
                (100.0 * numTicks / totalTicks),
                precision,
                etaSecs,
                precision,
                elapsedSecs,
                precision,
                ticksPerSec,
            );

        final switch (lineLocation)
        {
            case LineLocation.first:
            case LineLocation.middle:
                output.flush();
                break;
            case LineLocation.last:
                output.writeln();
                output.flush();
                break;
        }
    }


    void printJsonProgressLine(LineLocation lineLocation)
    {
        enum formatPrefix = `{"ticks":%d,"elapsedSecs":%.*f`;
        enum formatRate = `,"ticksPerSec":%.*f`;
        enum formatNoRate = `,"ticksPerSec":"inf"`;
        enum formatEta = `,"etaSecs":%.*f,"total":%d`;
        enum formatSuffix = `}`;

        if (lineLocation == LineLocation.first)
            return;

        output.writef!formatPrefix(
            numTicks,
            precision,
            elapsedSecs,
        );
        if (elapsedSecs > 0)
            output.writef!formatRate(
                precision,
                ticksPerSec,
            );
        else
            output.writef!formatNoRate;

        if (hasETA)
            output.writef!formatEta(precision, etaSecs, totalTicks);

        output.writefln!formatSuffix;
        output.flush();
    }
}

unittest
{
    import std.array;
    import std.stdio;
    import vibe.data.json : parseJsonString;

    auto logFile = File.tmpfile();
    enum totalTicks = 5;
    auto progress = new ProgressMeter(totalTicks, 0, ProgressMeter.Format.json);
    progress.precision = 9;
    progress.output = logFile;

    progress.start();
    foreach (_; 0 .. totalTicks)
        progress.tick();
    progress.stop();

    logFile.rewind();
    auto statusLines = [
        parseJsonString(logFile.readln),
        parseJsonString(logFile.readln),
        parseJsonString(logFile.readln),
        parseJsonString(logFile.readln),
        parseJsonString(logFile.readln),
        parseJsonString(logFile.readln),
    ];

    assert(statusLines[0]["ticks"] == 1);
    assert(statusLines[1]["ticks"] == 2);
    assert(statusLines[2]["ticks"] == 3);
    assert(statusLines[3]["ticks"] == 4);
    assert(statusLines[4]["ticks"] == 5);
    assert(statusLines[5]["ticks"] == 5);

    assert(statusLines[0]["elapsedSecs"] <= statusLines[1]["elapsedSecs"]);
    assert(statusLines[1]["elapsedSecs"] <= statusLines[2]["elapsedSecs"]);
    assert(statusLines[2]["elapsedSecs"] <= statusLines[3]["elapsedSecs"]);
    assert(statusLines[3]["elapsedSecs"] <= statusLines[4]["elapsedSecs"]);
    assert(statusLines[4]["elapsedSecs"] <= statusLines[5]["elapsedSecs"]);

    assert(statusLines[0]["etaSecs"] >= statusLines[4]["etaSecs"]);
    assert(statusLines[5]["etaSecs"] == 0.0);
    assert(statusLines[5]["ticksPerSec"].get!double > 0.0);
}
