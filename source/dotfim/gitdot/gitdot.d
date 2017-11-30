module dotfim.gitdot.gitdot;

import dotfim.gitdot.gitfile;
import dotfim.gitdot.dotfile;

class NotManagedException : Exception
{ this(){super("Gitfile is not managed");} }

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

        // throw if gitFile is missing the {commentIndicator} fileHeader
        if (this.commentIndicator.empty)
            throw new NotManagedException();

        this.dotfile =
            new Dotfile(dfilePath, this.commentIndicator, createHeaderLine());
    }

    // Accepts dotfile (relative to gitPath) and prepares the gitfile
    static GitDot create(string dotfile, string commentIndicator, string gitPath, string dotPath)
    {
        import std.path, std.file;
        import std.range : array;

        string relDotFile = asRelativePath(dotfile, dotPath).array;

        // assert dotFile/dotPath begins with "."
        assert(relDotFile != "");
        assert(relDotFile[0] == '.',
                "Dotfiles are hidden... (begin with \".\")");

        // create gitFolder if dotfile resides in one
        string folder = relDotFile.dirName;
        if (folder != ".")
        {
            string newGitPath = buildPath(gitPath, folder);
            if (!exists(newGitPath))
                mkdirRecurse(newGitPath);
        }

        string gitFile = buildPath(gitPath, relDotFile);

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

        return new GitDot(gitFile, dotfile);
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

