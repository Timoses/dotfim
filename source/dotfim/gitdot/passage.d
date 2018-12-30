module dotfim.gitdot.passage;

import std.exception : enforce;

import dotfim.gitdot;
import dotfim.gitdot.dotfile;
import dotfim.gitdot.gitfile;

import std.stdio;

struct Passage
{
    enum Type
    {
        Invalid,
        Git,
        Local,
        Private,
        Shebang
    }

    Type type;
    string[] lines;

    // set for Local type
    string localinfo;

    invariant
    {
        assert((type != Passage.Type.Local && type != Passage.Type.Private)
                    || localinfo.length,
                "Local passage must have localinfo specified");
    }

    this(const Passage other)
    {
        this.type = other.type;
        this.lines = other.lines.dup;
        this.localinfo = other.localinfo;
    }

    this(Type type, string[] lines, string localinfo = "")
    {
        this.type = type;
        this.lines = lines;
        this.localinfo = localinfo;
    }
}

/**
 * Passages:
 *  Header: <cI> GitDot.settings.header
 *  no indication: Git
 *  spanning several lines:
 *      # dotfim <Type> {
 *      <lines...>
 *      # }
 *  single line:
 *      #dotfim <Type>
 *      <line>
 */
class PassageHandler
{
    enum string controlStatement = "dotfim";
    enum string blockBeginIndicator = "{";
    enum string blockEndIndicator = "}";

    const(GitDot.Settings)* settings;
    string commentIndicator;

    class PassageHandlerException : Exception
    {
        import std.conv : to;
        this(int lineNumber, string msg) {
            super("(line "~lineNumber.to!string~"): "~msg); }
    }
    class UnexpectedStatement : PassageHandlerException
    {
        this(int lineNumber, string statement) {
            super(lineNumber, "Unexpected statement: "~statement); }
    }

    this(const ref GitDot.Settings settings)
    {
        this.settings = &settings;
    }

    Passage[] read(T)(string[] lines, bool managed)
    {
        import std.algorithm : find, findSplitAfter, canFind, startsWith;
        import std.range : front, popFront;
        import std.string : splitLines, split, strip, stripLeft;

        Passage[] passages;
        Passage.Type type;

        if (lines.front.startsWith("#!"))
        {
            passages ~= Passage(Passage.Type.Shebang, [lines.front.stripLeft("#!")]);
            lines.popFront;
        }

        if (!managed)
        {
            static if (is (T == Dotfile))
                return passages ~ Passage(Passage.Type.Private, lines,
                                this.settings.localinfo);
            else if (is (T == Gitfile))
                return passages ~ Passage(Passage.Type.Git, lines);
        }

        // true if previous line indicates a passage span (# { ... # })
        bool inPassage = false;
        string localinfo;

        foreach (int i, line; lines)
        {
            if (line.canFind(settings.header))
            {
                continue;
            }
            // Git files currently only contain Git lines
            else if (line.split
                        .startsWith([commentIndicator,
                                     controlStatement]))
            {
                type = Passage.Type.Invalid;

                auto control = line.findSplitAfter(controlStatement);

                if (control[0].length > 0)
                {
                    import std.string : split;
                    string[] statements = control[1].split;
                    if (statements[0] == blockEndIndicator)
                    {
                        enforce(inPassage, new UnexpectedStatement(i+1,
                                    blockEndIndicator));
                        inPassage = false;
                        continue;
                    }
                    else
                    {
                        enforce(!inPassage, new PassageHandlerException(i+1,
                                    "Cannot have a dotfim control statement "
                                    ~ "within a dotfim control block"));
                        import std.conv : parse, to;
                        import std.uni : asCapitalized;
                        string typestring = statements[0].asCapitalized.to!string;
                        type = typestring.parse!(Passage.Type);

                        bool hasLocalStatement = false;
                        static if (is (T == Gitfile))
                        {
                            if (type == Passage.Type.Local
                                   || type == Passage.Type.Private)
                            {
                                assert(statements.length > 1,
                                        "Required localinfo is missing "
                                        ~"for type " ~ type.to!string);
                                localinfo = statements[1];
                                hasLocalStatement = true;
                            }
                        }
                        else if (is (T == Dotfile))
                            localinfo = this.settings.localinfo;


                        if (statements.length > 1 + hasLocalStatement
                                && statements[1 + hasLocalStatement]
                                    == blockBeginIndicator)
                        {
                            inPassage = true;
                            passages ~= Passage(type, [],
                                                (type == Passage.Type.Local ||
                                                 type == Passage.Type.Private)
                                                ? localinfo : "");
                        }
                        continue;
                    }
                }
            }
            else if (inPassage)
            {
                passages[$-1].lines ~= line;
            }
            else if (type == Passage.Type.Invalid)
            {
                type = Passage.Type.Git;
                passages ~= Passage(type, [line]);
            }
            else if (type == Passage.Type.Git)
            {
                assert(passages[$-1].type == type);
                passages[$-1].lines ~= line;
            }
            else
            {
                passages ~= Passage(type, [line], localinfo);
                type = Passage.Type.Invalid;
            }
        }

        enforce(!inPassage, "Missing end of control block statement!");

        return passages;
    }

    string[] format(T)(const Passage passage, bool managed)
    {
        import std.conv : to;
        import std.format : format;
        import std.range : front;

        auto control = "%s %s ".format(this.commentIndicator,
                              this.controlStatement);

        final switch (passage.type) with (Passage.Type)
        {
            case Git:
                static if (is (T == Dotfile))
                    if (!managed)
                        return [];

                return passage.lines.dup;
            case Local:
                static if (is (T == Gitfile))
                    if (!managed && passage.localinfo == this.settings.localinfo)
                        return [];

                static if (is (T == Dotfile))
                    if (!managed)
                        return passage.lines.dup;

                control ~= Local.to!string;

                static if (is (T == Gitfile))
                    control ~= " " ~ passage.localinfo;

                if (passage.lines.length > 1)
                    control ~= " " ~ this.blockBeginIndicator;

                string[] lines;
                lines ~= [control] ~ passage.lines;

                if (passage.lines.length > 1)
                    lines ~= this.commentIndicator ~ " "
                                ~ this.controlStatement ~ " "
                                ~ this.blockEndIndicator;
                return lines;
            case Private:
                control ~= Private.to!string;

                static if (is (T == Gitfile))
                {
                    import std.algorithm : all, count;
                    import std.ascii : isHexDigit;
                    import std.conv : parse;
                    assert(passage.lines.length == 1
                            && passage.lines[0].dup.all!isHexDigit
                            && passage.lines[0].count == 32*2,
                            "A private passage in Gitfile should only always "
                            ~ "contain a one-line SHA256 hash!");

                    control ~= " " ~ this.settings.localinfo;

                    return [control] ~ passage.lines;
                }
                else
                {
                    if (passage.lines.length > 1)
                        control ~= " " ~ this.blockBeginIndicator;

                    string[] lines;
                    lines ~= [control] ~ passage.lines;

                    if (passage.lines.length > 1)
                        lines ~= this.commentIndicator ~ " "
                                ~ this.controlStatement ~ " "
                                ~ this.blockEndIndicator;

                    return lines;
                }
            case Shebang:
                assert(commentIndicator == "#",
                        "Shebang is only valid for '#' comment indicator");
                assert(passage.lines.length == 1,
                        "Shebang passage should only contain one line");
                return ["#!" ~ passage.lines.front];
            case Invalid:
                assert(false);

        }
    }

    Passage hash(Passage passage) const
    {
        import std.digest.sha :sha256Of;
        import std.array : join;
        import std.format : format;
        ubyte[32] hash = sha256Of(passage.lines.join);
        return Passage(passage.type, ["%(%02x%)".format(hash)],
                                passage.localinfo);
    }
}

version(unittest_all) unittest
{
    GitDot.Settings settings;

    import std.format;
    import std.string;
string[] lines=q"EOS
Sync 1
# %s
# dotfim local
local 1
# dotfim local {
local 2
local 3
# dotfim }
Synd 2
EOS".format(settings.header).splitLines;
    Passage[] passages = [
        Passage(Passage.Type.Git, ["Sync 1"]),
        Passage(Passage.Type.Local, ["local 1"], settings.localinfo),
        Passage(Passage.Type.Local, ["local 2", "local 3"], settings.localinfo),
        Passage(Passage.Type.Git, ["Synd 2"])];
    auto ph = new PassageHandler(settings);
    ph.commentIndicator = "#";
    Passage[] readpassages = ph.read!Dotfile(lines, true);

    assert(readpassages == passages);
}
