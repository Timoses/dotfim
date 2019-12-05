module dotfim.gitdot.passage;

import std.array : array;
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

class PassageHandlerException : Exception
{
    import std.conv : to;
    this(size_t lineNumber, string msg) {
        super("(line "~lineNumber.to!string~"): "~msg); }
}
class UnexpectedStatement : PassageHandlerException
{
    this(size_t lineNumber, string statement) {
        super(lineNumber, "Unexpected statement: "~statement); }
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
static class PassageHandler
{
    enum string controlStatement = "dotfim";
    enum string blockBeginIndicator = "{";
    enum string blockEndIndicator = "}";

    static Passage[] read(T)(const(GitDot.Settings) settings, string[] lines, bool managed)
    {
        import std.algorithm : filter, find, findSplitAfter, canFind, startsWith,
                               map, group;
        import std.range : front, popFront, empty;
        import std.string : splitLines, split, strip, stripLeft;

        Passage[] passages;
        Passage.Type type;

        if (lines.empty)
            return passages;

        // Remove duplicate empty lines
        lines = lines.group!((l1,l2) => l1 == l2 && l1 == "")
                     .map!(g => g[0]).array;

        if (lines.front.startsWith("#!"))
        {
            passages ~= Passage(Passage.Type.Shebang, [lines.front.stripLeft("#!")]);
            lines.popFront;
        }

        if (!managed)
        {
            static if (is (T == Dotfile))
                passages ~= Passage(Passage.Type.Private, lines, settings.localinfo);
            else if (is (T == Gitfile))
                passages ~= Passage(Passage.Type.Git, lines);
        }
        else
        {
            // true if previous line indicates a passage span (# { ... # })
            bool inPassage = false;
            string localinfo;

            foreach (size_t i, line; lines)
            {
                if (line.canFind(settings.header))
                {
                    continue;
                }
                // Git files currently only contain Git lines
                else if (line.split
                            .startsWith([settings.commentIndicator,
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
                                localinfo = settings.localinfo;


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
        }

        return passages.map!((ref p) {
                     import std.algorithm : stripLeft, stripRight;
                     // remove duplicate consecutive empty lines
                     p.lines = p.lines
                                .group!((l1,l2) => l1 == l2 && l1 == "")
                                .map!(g => g[0])
                                .array.stripLeft("").stripRight("");
                     return p;
                })
                  // remove passages with no lines or only an empty line
                  .filter!(p => p.lines.length &&
                                 !(p.lines.length == 1 &&
                                   p.lines[0] == ""))
                  .array;
    }

    static string[] format(T)(const(GitDot.Settings) settings, const Passage passage, bool managed)
    {
        import std.conv : to;
        import std.format : format;
        import std.range : front;

        auto control = "%s %s ".format(settings.commentIndicator,
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
                    if (!managed && passage.localinfo == settings.localinfo)
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
                    lines ~= settings.commentIndicator ~ " "
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

                    control ~= " " ~ settings.localinfo;

                    return [control] ~ passage.lines;
                }
                else
                {
                    if (passage.lines.length > 1)
                        control ~= " " ~ this.blockBeginIndicator;

                    string[] lines;
                    lines ~= [control] ~ passage.lines;

                    if (passage.lines.length > 1)
                        lines ~= settings.commentIndicator ~ " "
                                ~ this.controlStatement ~ " "
                                ~ this.blockEndIndicator;

                    return lines;
                }
            case Shebang:
                assert(settings.commentIndicator == "#",
                        "Shebang is only valid for '#' comment indicator not for "
                        ~ "\"" ~ settings.commentIndicator ~ "\"!");
                assert(passage.lines.length == 1,
                        "Shebang passage should only contain one line");
                return ["#!" ~ passage.lines.front];
            case Invalid:
                assert(false);

        }
    }

    static Passage hash(Passage passage)
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
    import dotfim.dotfim;
    GitDot gd = new GitDot("", "", DotfileManager.Settings());

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
EOS".format(gd.settings.header).splitLines;
    Passage[] passages = [
        Passage(Passage.Type.Git, ["Sync 1"]),
        Passage(Passage.Type.Local, ["local 1"], gd.settings.localinfo),
        Passage(Passage.Type.Local, ["local 2", "local 3"], gd.settings.localinfo),
        Passage(Passage.Type.Git, ["Synd 2"])];
    gd.settings.commentIndicator = "#";
    Passage[] readpassages = PassageHandler.read!Dotfile(gd.settings, lines, true);

    assert(readpassages == passages);
}
