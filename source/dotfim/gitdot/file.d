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
    const(GitDot.Settings)* settings;

    private string _commentIndicator;
    @property string commentIndicator() { return this._commentIndicator; }
    @property void commentIndicator(string ci)
    {
        this._commentIndicator = ci;
        this.passageHandler.commentIndicator = ci;
    }

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

    static PassageHandler passageHandler;

    invariant
    {
        assert(!this._managed || (this._managed && this._commentIndicator.length),
                "File " ~ this._file ~ " is managed but has no commentIndicator!");
        //assert(!this._managed || (this._managed && this.hash.length),
        //        "File " ~ this._file ~ " is managed but has no hash!");
    }

    this(ref const GitDot.Settings settings, string file)
    {
        this.settings = &settings;
        this._file = file;

        if (!passageHandler)
            this.passageHandler = new PassageHandler(*this.settings);
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
        this._file = "";
        this._raw = lines;
        loadInternal!T();
    }

    private void loadInternal(this T)()
    {
        this._passages.length = 0;
        this.managed = false;
        this.commentIndicator = "";

        retrieveHeaderInfo();

        if (this.commentIndicator.length)
            this._managed = true;

        try this._passages = passageHandler.read!T(this._raw, this._managed);
        catch (PassageHandler.PassageHandlerException e)
            enforce(false, "Failed to load file \"" ~ this.file ~ "\"! Error: "
                    ~ typeof(e).stringof ~ " - " ~ e.msg);
    }

    private void retrieveHeaderInfo()
    {
        assert(this.settings.header.length > 0, "Header in settings is empty");
        import std.algorithm : find, findSplitAfter, findSplitBefore, canFind;
        import std.range : front;

        auto headLine = this._raw.find!(line => line.canFind(this.settings.header));

        if (!headLine.length)
            return;

        auto split =
            headLine.front.findSplitBefore(this.settings.header);

        import std.string : empty, strip;
        if (split[1].empty)
            return;
        else
        {
            this.commentIndicator = split[0].strip;

            if (this.classinfo.name == "dotfim.gitdot.dotfile.Dotfile")
            {
                auto hashsplit = split[1].findSplitAfter(this.settings.header);
                enforce(hashsplit[1].strip.length, "Missing hash in managed dotfile");
                this.hash = hashsplit[1].strip;
            }
        }
    }

    void write(this T)()
    {
        debug logDebug("GitDotFile:write %s %s",
                 T.stringof, this.file);

        string[] lines;

        if (this.managed)
        {
            lines ~= commentIndicator ~ " " ~ this.settings.header;
            static if (is (T == Dotfile))
                lines[$-1] ~= " " ~ this.hash;
        }


        foreach (passage; passages)
        {
            lines ~= this.passageHandler.format!T(passage, this.managed);
        }

        File f = File(this.file, "w");
        import std.algorithm : each;
        lines.each!(line => f.writeln(line));
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
        //writeln(this._passages.hash); // ... store type passages if hash didn't change -> return them
        return this._passages.filter!(p => types.canFind(p.type)).array;
    }
}

