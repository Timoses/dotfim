module dotfim.section.git;


import dotfim.section;

class GitSection : Section
{

    private string _gitHash;

    @property gitHash(string newHash)
    {
        this._gitHash = newHash;
    }
    @property gitHash() { return this._gitHash; }

    this()
    {
        this.name = "Git";
    }

    override string[] getHeaderTitle()
    {
        return ["DotfiM - Git Section"];
    }

    override string[] getHeader()
    {
        assert(this._gitHash != "");
        return getHeaderTitle() ~
                 [" Changes to this section are synchronized with your dotfiles repo",
                 " Git Commit Hash: " ~ this._gitHash];
    }

    override string[] getFooter()
    {
        return ["DotfiM - end of Git Section"];
    }

    string retrieveGitHash(string[] lines)
    {
        static immutable string findPrefix = " Git Commit Hash: ";
        foreach (line; lines)
        {
            import std.algorithm : canFind;
            if (line.canFind(findPrefix))
            {
                import std.algorithm : findSplitAfter;
                return line.findSplitAfter(findPrefix)[1];
            }
        }

        return "";
    }

    override bool load(string[] lines, string commentIndicator)
    {
        super.load(lines, commentIndicator);

        this._gitHash = retrieveGitHash(this.get(Part.Header));

        import std.exception : enforce;
        import std.string : empty;
        scope(failure) this.bLoaded = false;
        enforce(!this._gitHash.empty, "Git Commit Hash could not be loaded from Git Section");

        return this.bLoaded;
    }

    override void generate()
    {
        this.set(Part.Header, this.getHeader());
        this.set(Part.Footer, this.getFooter());
    }
}
