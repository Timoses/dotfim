module dotfim.gitdot.gitdot;

import dotfim.gitdot.gitfile;
import dotfim.gitdot.dotfile;

class NotManagedException : Exception
{ this(){super("Gitfile is not managed");} }

class GitDot
{
    Gitfile git;
    Dotfile dot;

    // Both dotfile and gitfile have to contain the following
    // as the first line:
    // {commentIndicator} {fileHeader}
    static immutable string fileHeader = "This dotfile is managed by DotfiM";
    string commentIndicator;

    this(string gfilePath, string dfilePath)
    {
        this.git =
            new Gitfile(gfilePath);

        import std.string : empty;
        this.commentIndicator = git.retrieveCommentIndicator(fileHeader);

        // throw if gitFile is missing the {commentIndicator} fileHeader
        if (this.commentIndicator.empty)
            throw new NotManagedException();

        this.dot =
            new Dotfile(dfilePath, this.commentIndicator, createHeaderLine());
    }

    // Accepts relFile which is the dotfile or gitfile relative to its
    // dotdir or gitdir, respectively
    static GitDot create(string relFile, string commentIndicator, string gitdir, string dotdir)
    {
        import std.path, std.file;
        import std.range : array;

        // assert dotFile/dotdir begins with "."
        assert(relFile != "");
        import std.exception : enforce;
        enforce(relFile[0] == '.',
                "Dotfiles are hidden... (begin with \".\")");

        // create gitFolder if dotfile resides in one
        string folder = relFile.dirName;
        if (folder != ".")
        {
            string newGitPath = buildPath(gitdir, folder);
            if (!exists(newGitPath))
                mkdirRecurse(newGitPath);
        }

        string gitFile = buildPath(gitdir, relFile);

        import std.stdio : File;
        // if it exists prepend {commentIndicator} fileHeader
        if(exists(gitFile))
        {
            import std.conv : to;
            File fgit = File(gitFile, "a+");
            string[] gitLines;
            foreach (line; fgit.byLine)
                gitLines ~= line.to!string;
            import std.file : remove;
            fgit.close();
            remove(gitFile);
            fgit.open(gitFile, "w");
            fgit.writeln(commentIndicator ~ " " ~ fileHeader);
            foreach(line; gitLines)
                fgit.writeln(line);
            fgit.close();
        }
        else // else create new file with {commentIndicator} fileHeader
        {
            File newGit = File(gitFile, "w");
            newGit.writeln(commentIndicator ~ " " ~ fileHeader);
            newGit.close();
        }

        string dotFile = buildPath(dotdir, relFile);

        return new GitDot(gitFile, dotFile);
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

