module dotfim.gitdot.gitfile;


class Gitfile
{
    string file;

    private
    {
        string[] _rawLines;

        string _headerLine;
        string[] _gitLines;
    }

    this (string file)
    {
        this.file = file;

        // read contents of gitFile
        read();
    }

    void read()
    {
        import std.conv : to;
        import std.stdio : File;
        File git = File(this.file, "r");
        foreach (line; git.byLine)
            this._rawLines ~= line.to!string;
        git.close();

        import std.range : take, drop;
        if (this._rawLines.length > 0)
        {
            this._headerLine = this._rawLines.take(1)[0];
            this._gitLines = this._rawLines.drop(1);
        }
    }

    // retrieves commendIndicator from headerLine
    // in the format: "{CommentIndicator} {fileHeader}"
    string retrieveCommentIndicator(string fileHeader)
    {
        import std.algorithm.searching : findSplitBefore;
        auto split = this._headerLine.findSplitBefore(fileHeader);

        import std.string : empty, strip;
        if (split[1].empty)
            return "";
        else
            return split[0].strip;
    }

    void write(bool bLeaveHeader = false)
    {
        this._rawLines.length = 0;
        if (!bLeaveHeader)
            this._rawLines ~= _headerLine;
        this._rawLines ~= _gitLines;

        import std.stdio : File;
        import std.file : remove;
        remove(this.file);
        File git = File(this.file, "w");
        foreach (line; this._rawLines)
            git.writeln(line);
        git.close();

    }

    @property string[] gitLines() { return this._gitLines; }
    @property void gitLines(string[] lines) {
        this._gitLines = lines; }
}

