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
import std.array;
import std.datetime;
import std.format;
import std.process;
import std.range;
import std.stdio;

private
{
    __gshared LogLevel minLevel = LogLevel.info;
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

    auto origStderr = stderr;
    stderr = File.tmpfile();
    scope (exit)
    {
        stderr.close();
        stderr = origStderr;
    }

    logJsonError("error", "mysterious observation", "secret", 42);

    stderr.rewind();
    auto observed = parseJsonString(stderr.readln);

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
            File output = stderr;

            synchronized if (output.isOpen)
            {
                output.writeln(txt.data);
                output.flush();
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

    auto origStderr = stderr;
    stderr = File.tmpfile();
    scope (exit)
    {
        stderr.close();
        stderr = origStderr;
    }

    void doSomething()
    {
        mixin(traceExecution!(LogLevel.error));

        import core.thread : Thread;
        import core.time : dur;

        Thread.getThis.sleep(dur!"hnsecs"(50));
    }

    doSomething();
    stderr.rewind();

    enum functionFQN = ctRegex!`dalicious\.log\.__unittest_L[0-9]+_C[0-9]+\.doSomething`;
    auto observed1 = parseJsonString(stderr.readln);
    auto observed2 = parseJsonString(stderr.readln);

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
