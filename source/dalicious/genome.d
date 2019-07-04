/**
    Some functions to work with FASTA data.

    Copyright: © 2019 Arne Ludwig <arne.ludwig@posteo.de>
    License: Subject to the terms of the MIT license, as written in the
             included LICENSE file.
    Authors: Arne Ludwig <arne.ludwig@posteo.de>
*/
module dalicious.genome;

import std.algorithm :
    count,
    equal,
    find,
    joiner,
    startsWith;
import std.ascii : newline;
import std.array :
    appender, array;
import std.conv : to;
import std.exception : enforce;
import std.format :
    format,
    formattedRead;
import std.range :
    chain,
    chunks,
    drop,
    ElementType,
    empty,
    front,
    isBidirectionalRange,
    only,
    popBack,
    popFront,
    take,
    walkLength;
import std.stdio : File;
import std.string : indexOf, lineSplitter, outdent;
import std.traits : isSomeChar, isSomeString;
import std.typecons : tuple, Tuple;


/// Lines starting with this character designate the beginning of a FASTA record.
enum headerIndicator = '>';


/**
    Calculate the sequence length of the first record in fastaFile. Returns
    the length of the next record in fastaFile if it is a File object.
*/
size_t getFastaLength(in string fastaFile)
{
    alias isHeaderLine = (line) => line.length > 0 && line[0] == headerIndicator;

    return File(fastaFile).getFastaLength();
}

/// ditto
size_t getFastaLength(File fastaFile)
{
    alias isHeaderLine = (line) => line.length > 0 && line[0] == headerIndicator;

    auto fastaLines = fastaFile
        .byLine
        .find!isHeaderLine;

    enforce(!fastaLines.empty, "cannot determine FASTA length: file has no records");

    // ignore header
    fastaLines.popFront();

    char peek()
    {
        import core.stdc.stdio : getc, ungetc;
        import std.exception : errnoEnforce;

        auto c = getc(fastaFile.getFP());
        ungetc(c, fastaFile.getFP());

        errnoEnforce(!fastaFile.error);

        return cast(char) c;
    }

    // sum length of all sequence lines up to next record
    size_t length;

    if (peek() == headerIndicator)
        return 0;
    foreach (line; fastaLines)
    {
        length += line.length;

        if (peek() == headerIndicator)
            break;
    }

    return length;
}

///
unittest
{
    import std.process : pipe;

    string fastaRecordData = q"EOF
        >sequence1
        CTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCT
        AACCCTAACCCTAACCCTAACCCTAACCCTAACAACCCTAACCCTAACCC
EOF".outdent;
    auto fastaFile = pipe();
    fastaFile.writeEnd.write(fastaRecordData);
    fastaFile.writeEnd.close();

    auto fastaLength = getFastaLength(fastaFile.readEnd);

    assert(fastaLength == 100);
}

///
unittest
{
    import std.process : pipe;

    string fastaRecordData = q"EOF
        >sequence1
        CTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCT
        AACCCTAACCCTAACCCTAACCCTAACCCTAACAACCCTAACCCTAACCC
        >sequence2
        AACCCTAACCCTAACCCTAACCCTAACCCTAACAACCCTAACCCTAACCC
EOF".outdent;
    auto fastaFile = pipe();
    fastaFile.writeEnd.write(fastaRecordData);
    fastaFile.writeEnd.close();

    auto fastaLength1 = getFastaLength(fastaFile.readEnd);
    auto fastaLength2 = getFastaLength(fastaFile.readEnd);

    assert(fastaLength1 == 100);
    assert(fastaLength2 == 50);
}

unittest
{
    import std.exception : assertThrown;
    import std.process : pipe;

    auto fastaFile = pipe();
    fastaFile.writeEnd.close();

    assertThrown(getFastaLength(fastaFile.readEnd));
}

template PacBioHeader(T) if (isSomeString!T)
{
    struct PacBioHeader
    {
        static enum headerFormat = ">%s/%d/%d_%d %s";

        T name;
        size_t well;
        size_t qualityRegionBegin;
        size_t qualityRegionEnd;
        string additionalInformation;

        /// Construct a `PacBioHeader!T` from `header`.
        this(T header)
        {
            this.parse(header);
        }

        /// Assign new `header` data.
        void opAssign(T header)
        {
            this.parse(header);
        }

        /// Builds the header string.
        S to(S : T)() const
        {
            return buildHeader();
        }

        private T buildHeader() const
        {
            return format!headerFormat(
                name,
                well,
                qualityRegionBegin,
                qualityRegionEnd,
                additionalInformation,
            );
        }

        private void parse(in T header)
        {
            auto numMatches = header[].formattedRead!headerFormat(
                name,
                well,
                qualityRegionBegin,
                qualityRegionEnd,
                additionalInformation,
            );

            assert(numMatches == 5);
        }
    }
}

///
unittest
{
    string header = ">name/1/0_1337 RQ=0.75";
    auto pbHeader1 = PacBioHeader!string(header);

    assert(pbHeader1.to!string == ">name/1/0_1337 RQ=0.75");
    assert(pbHeader1.name == "name");
    assert(pbHeader1.well == 1);
    assert(pbHeader1.qualityRegionBegin == 0);
    assert(pbHeader1.qualityRegionEnd == 1337);
    assert(pbHeader1.additionalInformation == "RQ=0.75");

    PacBioHeader!string pbHeader2 = header;

    assert(pbHeader2 == pbHeader1);
}

/// Convenience wrapper around `PacBioHeader!T(T header)`.
PacBioHeader!T parsePacBioHeader(T)(T header)
{
    return typeof(return)(header);
}

///
unittest
{
    string header = ">name/1/0_1337 RQ=0.75";
    auto pbHeader1 = header.parsePacBioHeader();

    assert(pbHeader1.to!string == ">name/1/0_1337 RQ=0.75");
    assert(pbHeader1.name == "name");
    assert(pbHeader1.well == 1);
    assert(pbHeader1.qualityRegionBegin == 0);
    assert(pbHeader1.qualityRegionEnd == 1337);
    assert(pbHeader1.additionalInformation == "RQ=0.75");
}

/**
    Get the complement of a DNA base. Only bases A, T, C, G will be translated;
    all other characters are left as is. Replacement preserves casing of
    the characters.
*/
C complement(C)(C base) if (isSomeChar!C)
{
    import std.range : zip;

    enum from = `AGTCagtc`;
    enum to = `TCAGtcag`;

    switch (base)
    {
        static foreach (conv; zip(from, to))
        {
            case conv[0]:
                return conv[1];
        }
        default:
            return base;
    }
}

/**
    Compute the reverse complement of a DNA sequence. Only bases A, T, C, G
    will be translated; all other characters are left as is. Replacement
    preserves casing of the characters.
*/
auto reverseComplementer(Range)(Range sequence)
        if (isBidirectionalRange!Range && isSomeChar!(ElementType!Range))
{
    import std.algorithm : map;
    import std.range : retro;

    return sequence
        .retro
        .map!complement;
}

/// ditto
T reverseComplement(T)(in T sequence) if (isSomeString!T)
{
    import std.array : array;

    return sequence[].reverseComplementer.array.to!T;
}

FastaRecord!T reverseComplement(T)(in FastaRecord!T fastaRecord) if (isSomeString!T)
{
    enum lineSep = FastaRecord!T.lineSep;
    auto header = fastaRecord.header;
    auto sequence = fastaRecord[].array.reverseComplement;
    auto builder = appender!T;

    builder.reserve(header.length + sequence.length + 2 * lineSep.length);

    builder ~= header;
    builder ~= lineSep;
    builder ~= sequence;
    builder ~= lineSep;

    return typeof(return)(builder.data);
}

///
unittest
{
    auto seq = "GGTTGTAAATTGACTGTTGTCTGCT\ngccaatctactggtgggggagagat";
    auto revComp = "atctctcccccaccagtagattggc\nAGCAGACAACAGTCAATTTACAACC";

    assert(seq.reverseComplement == revComp);
    assert(seq.reverseComplementer.equal(revComp));

    auto fastaRecord1 = q"EOF
        >sequence1
        CTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCT
        AACCCTAACCCTAACCCTAACCCTAACCCTAACAACCCTAACCCTAACCC
EOF".outdent.parseFastaRecord;
    auto fastaRecord1RevComp = fastaRecord1.reverseComplement;

    assert(fastaRecord1RevComp.header == ">sequence1");
    assert(fastaRecord1RevComp[].equal("GGGTTAGGGTTAGGGTTGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAGGGTTAG"));
    assert(fastaRecord1RevComp[0 .. 5].equal("GGGTT"));
    assert(fastaRecord1RevComp.toFasta(13).equal(q"EOF
        >sequence1
        GGGTTAGGGTTAG
        GGTTGTTAGGGTT
        AGGGTTAGGGTTA
        GGGTTAGGGTTAG
        GGTTAGGGTTAGG
        GTTAGGGTTAGGG
        TTAGGGTTAGGGT
        TAGGGTTAG
EOF".outdent));
}
