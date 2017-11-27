module dotfim.gitdot.dotfile;

import std.file;
import std.path;
import std.conv;

import std.stdio;

import dotfim.section;
import dotfim.git;

class Dotfile
{
    string file;

    private
    {
        // read, updated and written
        string[] _rawLines;

        // read
        string _headerLine;
    }

    SectionHandler sectionHandler;

    // whether Dotfile is already managed by DotfiM
    bool managed;

    this(string file, string commentIndicator, string managedHeader)
    {
        this.file = file;
        this._headerLine = managedHeader;

        {
            // Read content of home dotfile
            File home = File(this.file, "a+");
            foreach(line; home.byLine)
                this._rawLines ~= line.to!string;
            home.close;
        }

        this.sectionHandler = new SectionHandler(commentIndicator);

        import std.range : empty;
        string[] customLines;
        if (!this._rawLines.empty && this._rawLines[0] == managedHeader)
        {
            this.managed = true;
            customLines = this.sectionHandler.load(this._rawLines[1..$]);
        }
        else
        {
            this.managed = false;
            customLines = this._rawLines;
        }

        // move all customLines to LocalSection
        this.sectionHandler.getSection!LocalSection.append(
                Section.Part.Content, customLines);
    }

    @property string gitHash()
    {
        if (this.managed)
            return getGitSection().gitHash;
        else
            return "";
    }

    @property void gitHash(string newHash)
    {
        getGitSection().gitHash = newHash;
    }

    @property string[] gitLines()
    {
        if (this.managed)
        {
            return getGitSection().get(Section.Part.Content);
        }
        else
            return [];
    }

    @property void gitLines(string[] lines)
    {
        getGitSection().set(Section.Part.Content, lines);
    }

    @property string[] localLines()
    {
        return this.sectionHandler.getSectionLines!(LocalSection)();
    }

    GitSection getGitSection()
    {
        return cast(GitSection)
            (this.sectionHandler.getSection!(GitSection));
    }

    void write()
    {
        this.sectionHandler.generateSections();

        this._rawLines.length = 0;
        this._rawLines ~= this._headerLine;
        this._rawLines ~= this.sectionHandler.getSectionLines!(GitSection)();
        this._rawLines ~= this.sectionHandler.getSectionLines!(LocalSection)();

        write(this._rawLines);
    }

    void write(string[] lines)
    {
        // replace file with new content
        import std.file;
        std.file.remove(this.file);
        File home = File(this.file, "w");
        foreach (line; lines)
            home.writeln(line);
    }
}
