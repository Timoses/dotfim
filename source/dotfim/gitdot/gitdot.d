module dotfim.gitdot.gitdot;

import dotfim.gitdot.gitfile;
import dotfim.gitdot.dotfile;

class GitDot
{
    Gitfile gitfile;
    Dotfile dotfile;

    // Both dotfile and gitfile have to contain the following
    // as the first line:
    // {commentIndicator} {fileHeader}
    static immutable string fileHeader = "This dotfile is managed by DotfiM";
    string commentIndicator;

    this(string gfilePath, string dfilePath)
    {
        this.gitfile =
            new Gitfile(gfilePath);

        import std.string : empty;
        this.commentIndicator = gitfile.retrieveCommentIndicator(fileHeader);
        import std.exception : enforce;
        enforce(!this.commentIndicator.empty, "Could not retrieve commentIndicator from gitfile. First line needs to be \"{CommentIndicator} " ~ fileHeader ~ "\"");

        this.dotfile =
            new Dotfile(dfilePath, this.commentIndicator, createHeaderLine());
    }

    string createHeaderLine()
    {
        import std.string : empty;
        // should not enter here if commentIndicator unknown
        assert(!this.commentIndicator.empty);
        import std.format : format;
        return format("%s %s", this.commentIndicator, fileHeader);
    }
}

