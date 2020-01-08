/**
    Convenience wrappers for executing subprocesses.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.process;


import std.algorithm :
    endsWith,
    filter;
import std.array : array;
import std.process :
    kill,
    Redirect,
    Config,
    pipeProcess,
    pipeShell,
    ProcessPipes,
    wait;
import std.range.primitives;
import std.traits : isSomeString;
import vibe.data.json : toJson = serializeToJson;

import std.range.primitives :
    ElementType,
    isInputRange;
import std.traits : isSomeString;
import std.typecons : Flag, Yes;


import dalicious.log : LogLevel;

/**
    Execute command and return the output. Logs execution and throws an
    exception on failure.

    Params:
        command  = A range that is first filtered for non-null values. The
                   zeroth element of the resulting range is the program and
                   any remaining elements are the command-line arguments.
        workdir  = The working directory for the new process. By default the
                   child process inherits the parent's working directory.
        logLevel = Log level to log execution on.
    Returns:
        Output of command.
    Throws:
        std.process.ProcessException on command failure
*/
string executeCommand(Range)(
    Range command,
    const string workdir = null,
    LogLevel logLevel = LogLevel.diagnostic,
)
        if (isInputRange!Range && isSomeString!(ElementType!Range))
{
    import std.process : Config, execute;

    string output = command.executeWrapper!("command",
            sCmd => execute(sCmd, null, // env
                Config.none, size_t.max, workdir))(logLevel);
    return output;
}

///
unittest
{
    auto greeting = executeCommand(["echo", "hello", "world"]);

    assert(greeting == "hello world\n");
}


/**
    Execute shellCommand and return the output. Logs execution on
    LogLevel.diagnostic and throws an exception on failure.

    Params:
        shellCommand  = A range command that first filtered for non-null
                        values, then joined by spaces and then passed verbatim
                        to the shell.
        workdir       = The working directory for the new process. By default
                        the child process inherits the parent's
                        working directory.
        logLevel      = Log level to log execution on.
    Returns:
        Output of command.
    Throws:
        std.process.ProcessException on command failure
*/
string executeShell(Range)(
    Range shellCommand,
    const string workdir = null,
    LogLevel logLevel = LogLevel.diagnostic,
)
        if (isInputRange!Range && isSomeString!(ElementType!Range))
{
    import std.algorithm : joiner;
    import std.conv : to;
    import std.process : Config, executeShell;

    string output = shellCommand.executeWrapper!("shell",
            sCmd => executeShell(sCmd.joiner(" ").to!string, null, // env
                Config.none, size_t.max, workdir))(logLevel);

    return output;
}

///
unittest
{
    auto greeting = executeShell(["echo", "hello", "world", "|", "rev"]);

    assert(greeting == "dlrow olleh\n");
}


/**
    Execute script and return the output. Logs execution on
    LogLevel.diagnostic and throws an exception on failure.

    Params:
        script   = A range command that first filtered for non-null values and
                   escaped by std.process.escapeShellCommand. The output of
                   this script is piped to a shell in
                   [Unofficial Bash Strict Mode][ubsc], ie `sh -seu o pipefail`.
        workdir  = The working directory for the new process. By default the
                   child process inherits the parent's working directory.
        logLevel = Log level to log execution on.
    Returns:
        Output of command.
    Throws:
        std.process.ProcessException on command failure

    [ubsc]: http://redsymbol.net/articles/unofficial-bash-strict-mode/
*/
string executeScript(Range)(
    Range script,
    const string workdir = null,
    LogLevel logLevel = LogLevel.diagnostic,
)
        if (isInputRange!Range && isSomeString!(ElementType!Range))
{
    import std.process : Config, executeShell;

    string output = script.executeWrapper!("script",
            sCmd => executeShell(sCmd.buildScriptLine, null, // env
                Config.none, size_t.max, workdir))(logLevel);

    return output;
}

///
unittest
{
    auto greeting = executeScript(["echo", "echo", "rock", "&&", "echo", "roll"]);

    assert(greeting == "rock\nroll\n");
}

private string executeWrapper(string type, alias execCall, Range)(Range command, LogLevel logLevel)
        if (isInputRange!Range && isSomeString!(ElementType!Range))
{
    import dalicious.log : logJson;
    import std.array : array;
    import std.algorithm :
        filter,
        map,
        min;
    import std.format : format;
    import std.process : ProcessException;
    import std.string : lineSplitter;
    import vibe.data.json : Json;

    auto sanitizedCommand = command.filter!"a != null".array;

    logJson(
        logLevel,
        "action", "execute",
        "type", type,
        "command", sanitizedCommand.map!Json.array,
        "state", "pre",
    );
    auto result = execCall(sanitizedCommand);
    logJson(
        logLevel,
        "action", "execute",
        "type", type,
        "command", sanitizedCommand.map!Json.array,
        "output", result
            .output[0 .. min(1024, $)]
            .lineSplitter
            .map!Json
            .array,
        "exitStatus", result.status,
        "state", "post",
    );
    if (result.status > 0)
    {
        throw new ProcessException(
                format("process %s returned with non-zero exit code %d: %s",
                sanitizedCommand[0], result.status, result.output));
    }

    return result.output;
}

private string buildScriptLine(in string[] command)
{
    import std.process : escapeShellCommand;

    return escapeShellCommand(command) ~ " | sh -seu o pipefail";
}


/**
    Run command and returns an input range of the output lines.
*/
auto pipeLines(Range)(Range command, in string workdir = null)
        if (isInputRange!Range && isSomeString!(ElementType!Range))
{
    auto sanitizedCommand = command.filter!"a != null".array;

    return new LinesPipe!ProcessInfo(ProcessInfo(sanitizedCommand, workdir));
}

/// ditto
auto pipeLines(in string shellCommand, in string workdir = null)
{
    return new LinesPipe!ShellInfo(ShellInfo(shellCommand, workdir));
}

unittest
{
    import std.algorithm : equal;
    import std.range : only, take;

    auto cheers = pipeLines("yes 'Cheers!'");
    assert(cheers.take(5).equal([
        "Cheers!",
        "Cheers!",
        "Cheers!",
        "Cheers!",
        "Cheers!",
    ]));

    auto helloWorld = pipeLines(only("echo", "Hello World!"));
    assert(helloWorld.equal(["Hello World!"]));
}

private struct ProcessInfo
{
    const(string[]) command;
    const(string) workdir;
}

private struct ShellInfo
{
    const(string) command;
    const(string) workdir;
}

private static final class LinesPipe(CommandInfo)
{
    static enum lineTerminator = "\n";

    private CommandInfo processInfo;
    private ProcessPipes process;
    private string currentLine;

    this(CommandInfo processInfo)
    {
        this.processInfo = processInfo;
    }

    ~this()
    {
        if (!(process.pid is null))
            releaseProcess();
    }

    void releaseProcess()
    {
        if (!process.stdout.isOpen)
            return;

        process.stdout.close();

        version (Posix)
        {
            import core.sys.posix.signal : SIGKILL;

            process.pid.kill(SIGKILL);
        }
        else
        {
            static assert(0, "Only intended for use on POSIX compliant OS.");
        }

        process.pid.wait();
    }

    private void ensureInitialized()
    {
        if (!(process.pid is null))
            return;

        process = launchProcess();

        if (!empty)
            popFront();
    }

    static if (is(CommandInfo == ProcessInfo))
        ProcessPipes launchProcess()
        {
            return pipeProcess(
                processInfo.command,
                Redirect.stdout,
                null,
                Config.none,
                processInfo.workdir,
            );
        }
    else static if (is(CommandInfo == ShellInfo))
        ProcessPipes launchProcess()
        {
            return pipeShell(
                processInfo.command,
                Redirect.stdout,
                null,
                Config.none,
                processInfo.workdir,
            );
        }

    void popFront()
    {
        ensureInitialized();
        assert(!empty, "Attempting to popFront an empty LinesPipe");
        currentLine = process.stdout.readln();

        if (currentLine.empty)
        {
            currentLine = null;
            releaseProcess();
        }

        if (currentLine.endsWith(lineTerminator))
            currentLine = currentLine[0 .. $ - lineTerminator.length];
    }

    @property string front()
    {
        ensureInitialized();
        assert(!empty, "Attempting to fetch the front of an empty LinesPipe");

        return currentLine;
    }

    @property bool empty()
    {
        ensureInitialized();

        if (!process.stdout.isOpen || process.stdout.eof)
        {
            releaseProcess();

            return true;
        }
        else
        {
            return false;
        }
    }
}


/**
    Returns true iff `name` can be executed via the process function in
    `std.process`. By default, `PATH` will be searched if `name` does not
    contain directory separators.

    Params:
        name       = Path to file or name of executable
        searchPath = Determines wether or not the path should be searched.
*/
version (Posix) bool isExecutable(scope string name, Flag!"searchPath" searchPath = Yes.searchPath)
{
    // Implementation is analogous to logic in `std.process.spawnProcessImpl`.
    import std.algorithm : any;
    import std.path : isDirSeparator;

    if (!searchPath || any!isDirSeparator(name))
        return isExecutableFile(name);
    else
        return searchPathFor(name) !is null;
}


version (Posix) private bool isExecutableFile(scope string path) nothrow
{
    // Implementation is analogous to private function `std.process.isExecutable`.
    import core.sys.posix.unistd : access, X_OK;
    import std.string : toStringz;

    return (access(path.toStringz(), X_OK) == 0);
}


version (Posix) private string searchPathFor(scope string executable)
{
    // Implementation is analogous to private function `std.process.searchPathFor`.
    import std.algorithm.iteration : splitter;
    import std.conv : to;
    import std.path : buildPath;
    static import core.stdc.stdlib;

    auto pathz = core.stdc.stdlib.getenv("PATH");
    if (pathz == null)  return null;

    foreach (dir; splitter(to!string(pathz), ':'))
    {
        auto execPath = buildPath(dir, executable);

        if (isExecutableFile(execPath))
            return execPath;
    }

    return null;
}
