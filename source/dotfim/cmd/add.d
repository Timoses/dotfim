module dotfim.cmd.add;

import std.algorithm : map;
import std.conv : to;
import std.path : asNormalizedPath, asAbsolutePath, asRelativePath;
import std.range : array;
import std.stdio : write, writeln, stderr, readln;

import dotfim.dotfim;

struct Add
{
    DotfileManager dfm;

    string[] dotfiles;

    this(lazy DotfileManager dfm, const string arg)
    { this(dfm, ["add", arg]); }
    this(lazy DotfileManager dfm, const string[] args = null)
    {
        import std.exception : enforce;
        enforce(args.length > 1, "Usage: dotfim add <file1> <file2> ... <fileN>");

        // sanitize paths
        this.dotfiles = args[1..$].map!((dotfile) =>
                asNormalizedPath(asAbsolutePath(dotfile).array).array
                .to!string).array;

        this.dfm = dfm;

        exec();
    }

    // Adds dotfiles to git repo and starts managing these files
    // The gitfile should not be managed
    // If the dotfile does not exist create it
    private void exec()
    {
        // update now since after add() new gitHash is commited eventually
        import dotfim.cmd.update;
        Update(this.dfm);

        writeln("--------DotfiM Add----------");

        import dotfim.gitdot;
        GitDot[] createdGitDots;

        with(this.dfm) foreach (file; this.dotfiles)
        {
            import std.algorithm : canFind;

            // Check if file is residing in either dotdir or gitdir
            bool bIsGitFile =
                file.canFind(settings.gitdir);
            bool bIsDotFile = bIsGitFile ? false
                : file.canFind(settings.dotdir);

            if (!(bIsGitFile || bIsDotFile))
            {
                // can't add a file outside of dot-/gitdir
                stderr.writeln("File ", file, " does neither reside within the dotfile path (", settings.dotdir, ") nor git path (", settings.gitdir, ")!\n\tSkipping");
                continue;
            }

            if (findGitDot(file))
            {
                stderr.writeln("File ", file, " is already managed by DotfiM");
                continue;
            }

            // should never reach assertNoEntry
            auto assertNoEntry = () { assert(bIsGitFile && bIsDotFile); return "";};

            string relFile = asRelativePath(file,
                    bIsGitFile ? settings.gitdir :
                    bIsDotFile ? settings.dotdir :
                    assertNoEntry()).array;

            import std.file : exists;
            import std.path : buildPath;
            // Check if file exists as either git- or dotfile
            bool bGitExists = exists(buildPath(settings.gitdir,
                        relFile));
            bool bDotExists = exists(buildPath(settings.dotdir,
                        relFile));

            if (!(bGitExists || bDotExists))
            {
                stderr.writeln("File ", file, " does neither exist as gitfile nor as dotfile.");
                continue;
            }

            assert(relFile != "");

            write("Please specify the comment indicator for file ",
                    relFile,
                    ": ");
            import std.string : chomp;
            string commentIndicator = readln().chomp();

            try
            {
                createdGitDots ~= GitDot.create(
                                          relFile,
                                          commentIndicator,
                                          settings.gitdir,
                                          settings.dotdir);
            }
            catch (Exception e)
            {
                import std.path : baseName;
                stderr.writeln(file.baseName, " - Error while creating: ", e.msg);
            }
        }

        with (this.dfm) if (createdGitDots.length > 0)
        {
            string addedFiles;

            foreach (gitdot; createdGitDots)
            {
                git.execute("add", gitdot.gitfile.file);
                addedFiles ~= asRelativePath(gitdot.gitfile.file,
                        settings.gitdir).array ~ "\n";
            }

            import std.algorithm : uniq;
            import std.range : array;
            gitdots = uniq!((e1,e2) => e1.dotfile.file == e2.dotfile.file)(createdGitDots ~ gitdots).array;

            commitAndPush("DotfiM Add: \n\n" ~ addedFiles);

            // Update dotfiles with new gitHash version
            // and add new dotfiles
            Update(this.dfm);
        }
    }
}
