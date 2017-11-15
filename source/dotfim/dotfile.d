module dotfim.dotfile;

import std.file;
import std.path;
import std.conv;

import std.stdio;

struct DfSectionHeaders
{
    string _updateHead1 = " - Update Section";
    string _updateHead2 = "  Additions to this section are committed to";
    string _updateHead3 = "  the dotfiles git repo and deleted from here thereafter.";
    string _updateTail = " - end of Update Section";
}

import dotfim.section;

class Dotfile
{
    string gitFile;
    string homeFile;

    // commit hash used for comparing dotfile versions
    string gitHash;

    // Whether file is already managed by us
    bool managed;

    // Both homeFile and gitFile have to contain the following
    // as the first line:
    // {commentIndicator} {fileHeader}
    static immutable string fileHeader = "This dotfile is managed by DotFiM";
    // Different dotfiles use different comment indicators
    string commentIndicator;

    SectionHandler sectionHandler;

    import std.string;
    import std.process : execute;

    this(string file, string homePath)
    {
        this.gitFile = file;
        this.homeFile = homePath ~ "/" ~ baseName(this.gitFile);

        this.commentIndicator = retrieveCommentIndicator(
                File(this.gitFile, "r").byLine.front.to!string);

        writeln("COMMENE: ", this.commentIndicator);
        import std.exception : enforce;
        enforce(!this.commentIndicator.empty, "Could not find commentIndicator. gitFile must begin with \"{CommentIndicator} " ~ fileHeader ~ "\"");

        assert(this.gitFile == "");

        this.sectionHandler = new SectionHandler(this);
    }

    void setHash(string hash) { this.gitHash = hash; }

    void update()
    {
        // Read content of home dotfile
        File home = File(this.homeFile, "a+");
        string[] homeFileLines;
        foreach(line; home.byLine)
            homeFileLines ~= line.to!string;
        home.close;

        this.managed = hasDotfimHeader(homeFileLines);


        // will contain lines not found in sections
        // and includes the fileHeader
        string[] customLines;

        if (this.managed)
        {
            customLines = sectionHandler.handleFromRaw(homeFileLines);
        }
        else
        {
            // add file header
            customLines = createHeaderLine()
                            ~ "" ~ homeFileLines;
        }

        string[] finalLines = customLines;

        // reduce trailing empty lines to 1
        import std.algorithm : strip;
        finalLines = finalLines.strip("");
        finalLines ~= "";

        this.sectionHandler.generateSections();
        finalLines ~= this.sectionHandler.getSection!(GitSection)();

        // replace file with new content
        std.file.remove(this.homeFile);
        home = File(this.homeFile, "w");
        foreach (line; finalLines)
            home.writeln(line);

        this.managed = true;
    }

    bool hasDotfimHeader(string[] lines)
    {
        if (!lines.empty
             && lines[0] == createHeaderLine())
            return true;
        else
            return false;
    }

    string retrieveCommentIndicator(lazy string line)
    {
        import std.algorithm.searching : findSplitBefore;
        auto split = line.findSplitBefore(Dotfile.fileHeader);
        if (split[1].empty)
            return "";
        else
            return split[0].chomp;
    }

    string createHeaderLine()
    {
        // should not enter here if commentIndicator unknown
        assert(!this.commentIndicator.empty);
        import std.format : format;
        return format("%s %s", this.commentIndicator, Dotfile.fileHeader);
    }

    void destroy()
    {
        this.sectionHandler.destroy();
    }
}

