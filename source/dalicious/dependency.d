/**
    This package holds function for easy verification of external tools'
    existence.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.dependency;


/**
    This struct can be used as a decorator to mark an external dependency of
    any symbol.
*/
struct ExternalDependency
{
    /// Name of the executable
    string executable;
    /// Name of the package that provides the executable.
    string package_;
    /// URL to the homepage of the package.
    string url;

    /// Get a human-readable string describing this dependency.
    string toString() const pure nothrow
    {
        if (package_ is null && url is null)
            return executable;
        else if (url is null)
            return executable ~ " (part of `" ~ package_ ~ "`)";
        else if (package_ is null)
            return executable ~ " (see " ~ url ~ ")";
        else
            return executable ~ " (part of `" ~ package_ ~ "`; see " ~ url ~ ")";
    }
}

// not for public use
static enum isExternalDependency(alias value) = is(typeof(value) == ExternalDependency);

unittest
{
    static assert(isExternalDependency!(ExternalDependency("someTool")));
    static assert(!isExternalDependency!"someTool");
}

import std.meta : Filter, staticMap;
import std.traits : getUDAs;

// not for public use
static enum ExternalDependency[] fromSymbol(alias symbol) = [Filter!(
    isExternalDependency,
    getUDAs!(symbol, ExternalDependency),
)];

unittest
{
    @ExternalDependency("someTool")
    void callSomeTool(in string parameter)
    {
        // calls `someTool`
    }

    static assert(fromSymbol!callSomeTool == [ExternalDependency("someTool")]);
}

/**
    Generates an array of external dependencies of `Modules`.

    Params:
        Modules = List of symbols to be checked.
*/
ExternalDependency[] externalDependencies(Modules...)()
{
    static assert(Modules.length > 0, "missing Modules");

    import std.array : array;
    import std.algorithm :
        joiner,
        sort,
        uniq;
    import std.meta : staticMap;
    import std.traits : getSymbolsByUDA;

    alias _getSymbolsByUDA(alias Module) = getSymbolsByUDA!(Module, ExternalDependency);
    alias byExecutableLt = (a, b) => a.executable < b.executable;
    alias byExecutableEq = (a, b) => a.executable == b.executable;

    ExternalDependency[][] deps = [staticMap!(
        fromSymbol,
        staticMap!(
            _getSymbolsByUDA,
            Modules,
        ),
    )];

    return deps.joiner.array.sort!byExecutableLt.release.uniq!byExecutableEq.array;
}

///
unittest
{
    struct Caller
    {
        @ExternalDependency("someTool")
        void callSomeTool(in string parameter)
        {
            // calls `someTool`
        }

        @ExternalDependency("otherTool")
        void callOtherTool(in string parameter)
        {
            // calls `otherTool`
        }
    }

    static assert(externalDependencies!Caller == [
        ExternalDependency("otherTool"),
        ExternalDependency("someTool"),
    ]);
}

unittest
{
    static assert(!is(externalDependencies));
}

/**
    Generates an array of external dependencies of `Modules`.

    Params:
        Modules = List of symbols to be checked.
*/
version(Posix) void enforceExternalDepencenciesAvailable(Modules...)()
{
    import std.array : array;
    import std.algorithm :
        map,
        startsWith;
    import std.format : format;
    import std.process : execute;
    import std.range : enumerate;
    import std.string : lineSplitter;

    enum modulesDeps = externalDependencies!Modules;

    static if (modulesDeps.length > 0)
    {
        enum whichBinary = "/bin/which";

        auto result = execute(
            [whichBinary, "--skip-alias", "--skip-functions"] ~
            modulesDeps
                .map!(extDep => extDep.executable)
                .array
        );

        ExternalDependency[] missingExternalTools;
        missingExternalTools.reserve(result.status);

        foreach (i, line; enumerate(lineSplitter(result.output)))
            if (line.startsWith(whichBinary))
                missingExternalTools ~= modulesDeps[i];

        if (missingExternalTools.length > 0)
            throw new ExternalDependencyMissing(missingExternalTools);
    }
    else
    {
        pragma(msg, "Info: your program has no external dependencies but checks for their availability.");
    }
}

/// ditto
version(Posix) deprecated alias enforceExternalToolsAvailable = enforceExternalDepencenciesAvailable;

///
unittest
{
    import std.exception : assertThrown;

    struct Caller
    {
        @ExternalDependency("/this/is/missing")
        @ExternalDependency("this_too_is_missing", "mypack", "http://example.com/")
        void makeCall() { }
    }

    assertThrown!ExternalDependencyMissing(enforceExternalDepencenciesAvailable!Caller());
    // Error message:
    //
    //     missing external tools:
    //     - /this/is/missing
    //     - this_too_is_missing (part of `mypack`; see http://example.com/)
    //
    //     Check your PATH and/or install the required software.
}


/// Thrown if one or more external dependencies are missing.
class ExternalDependencyMissing : Exception
{
    static enum errorMessage = "missing external tools:\n%-(- %s\n%)\n\nCheck your PATH and/or install the required software.";

    /// List of missing external depencencies.
    const(ExternalDependency[]) missingExternalTools;

    /**
        Params:
            missingExternalTools = List of missing external tools
            file                 = The file where the exception occurred.
            line                 = The line number where the exception
                                   occurred.
            next                 = The previous exception in the chain of
                                   exceptions, if any.
    */
    this(const(ExternalDependency[]) missingExternalTools, string file = __FILE__, size_t line = __LINE__,
         Throwable next = null) pure
    {
        import std.format : format;

        super(format!errorMessage(missingExternalTools), file, line, next);
        this.missingExternalTools = missingExternalTools;
    }
}
