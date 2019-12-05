module dotfim.gitdot.file;

import std.exception : enforce;
import std.range : array;

debug import vibe.core.log;

import dotfim.gitdot;
import dotfim.gitdot.dotfile;
import dotfim.gitdot.gitfile;
import dotfim.gitdot.passage;


import std.stdio;

abstract class GitDotFile
{
    GitDot.Settings settings;

    private bool _managed;
    @property bool managed() { return this._managed; }
    @property void managed(bool m) { this._managed = m; }

    private string[] _raw;
    @property string[] raw() { return this._raw; }
    private Passage[] _passages;

    private string _file;
    @property const(string) file() { return this._file; }

    // git hash of git- or dotfile
    string hash;

    invariant
    {
        assert(!this._managed || (this._managed && this.settings.commentIndicator.length),
                "File " ~ this._file ~ " is managed but has no commentIndicator!");
        //assert(!this._managed || (this._managed && this.hash.length),
        //        "File " ~ this._file ~ " is managed but has no hash!");
    }

    this(GitDot.Settings settings, string file)
    {
        this.settings = settings;
        this._file = file;
    }

    // Load file contents into passages, eventually adjust/confirm settings
    void load(this T)()
    {
        import std.file : readText;
        import std.string : splitLines;
        this._raw = this.file.readText.splitLines;
        loadInternal!T();
    }

    void load(this T)(string[] lines)
    {
        this._raw = lines;
        loadInternal!T();
    }

    private void loadInternal(this T)()
    {
        this._passages.length = 0;
        this.managed = false;

        this._managed = retrieveHeaderInfo();

        try this._passages = PassageHandler.read!T(this.settings, this._raw, this._managed);
        catch (PassageHandlerException e)
            enforce(false, "Failed to load file \"" ~ this.file ~ "\"! Error: "
                    ~ typeof(e).stringof ~ " - " ~ e.msg);

        debug logTrace("GitDotFile:loadInternal - Managed: %s", this._managed);
        debug logTrace("GitDotFile:loadInternal - Loaded passages: \n%(\t%s\n%)",
                        this._passages);
    }

    private bool retrieveHeaderInfo()
    {
        assert(this.settings.header.length > 0, "Header in settings is empty");
        import std.algorithm : find, findSplitAfter, findSplitBefore, canFind;
        import std.range : front;

        auto headLine = this._raw.find!(line => line.canFind(this.settings.header));

        if (!headLine.length)
            return false;

        auto split =
            headLine.front.findSplitBefore(this.settings.header);

        import std.string : empty, strip;
        if (split[1].empty)
            return false;
        else
        {
            this.settings.commentIndicator = split[0].strip;

            if (this.classinfo.name == "dotfim.gitdot.dotfile.Dotfile")
            {
                auto hashsplit = split[1].findSplitAfter(this.settings.header);
                enforce(hashsplit[1].strip.length, "Missing hash in managed dotfile " ~ this.file);
                this.hash = hashsplit[1].strip;
            }

            return true;
        }
    }

    void write(this T)()
    {
        debug logDebug("GitDotFile:write %s %s",
                 T.stringof, this.file);

        import std.algorithm : filter, each;
        import std.file : mkdirRecurse, exists;
        import std.path : dirName;

        string[] lines;

        auto shebangPassage = passages!(Passage.Type.Shebang);
        if (shebangPassage.length)
        {
            assert(shebangPassage.length == 1, "Only one Shebang passage allowed");
            lines ~= PassageHandler.format!T(this.settings, shebangPassage[0], this.managed);
            lines ~= "";
        }

        if (this.managed)
        {
            lines ~= this.settings.commentIndicator ~ " " ~ this.settings.header;
            static if (is (T == Dotfile))
                lines[$-1] ~= " " ~ this.hash;
            lines ~= "";
        }

        foreach (passage; passages.filter!
                                    (p => p.type != Passage.Type.Shebang).array)
        {
            lines ~= PassageHandler.format!T(this.settings, passage, this.managed);
            lines ~= "";
        }

        auto path = dirName(this.file);
        if (!path.exists)
            path.mkdirRecurse;

        File f = File(this.file, "w");
        lines.each!(line => f.writeln(line));

        static if (is (T == Dotfile))
        {
            if (lines.length == 1 && lines[0] == "")
            {
                import std.file : remove;
                this.file.remove;
            }
        }
    }

    // baggage
    void write(string[]){}
    void write(bool bLeaveHeader){}

    ref Passage[] passages()
    { return this._passages; }
    Passage[] passages(Passage.Type type)()
    { return passages!([type])(); }
    Passage[] passages(Passage.Type[] types)()
    {
        import std.algorithm : filter, canFind;
        return this._passages.filter!(p => types.canFind(p.type)).array;
    }
}

