module dotfim.cmd.add;

import std.algorithm : map;
import std.conv : to;
import std.path : asNormalizedPath, asAbsolutePath, asRelativePath;
import std.range : array;
import std.stdio : write, writeln, stderr, readln, stdout;

debug import vibe.core.log;

import dotfim.dotfim;

struct Add
{
    DotfileManager dfm;

    // dotfiles to be added
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
        debug logDebug("Add:exec %s", this.dotfiles);

        // sync now since after add() new gitHash is commited eventually
        import dotfim.cmd.sync;
        Sync(this.dfm);

        writeln("--------DotfiM Add----------");

        import dotfim.gitdot;
        bool bReloadDFM = false;
        GitDot[] addedGitDots;

        with(this.dfm) foreach (file; this.dotfiles)
        {
            import std.algorithm : canFind;

            // Check if file is residing in either dotdir or gitdir
            bool bIsGitFile =
                file.canFind(settings.gitdir);
            bool bIsDotFile = bIsGitFile ? false
                : file.canFind(settings.dotdir);

            debug logTrace("%s is Git: %b | Dot: %b", file, bIsGitFile, bIsDotFile);

            if (!(bIsGitFile || bIsDotFile))
            {
                // can't add a file outside of dot-/gitdir
                stderr.writeln("File ", file, " does neither reside within the dotfile path (", settings.dotdir, ") nor git path (", settings.gitdir, ")!\n\tSkipping");
                continue;
            }

            auto gitdot = findGitDot(file);
            if (gitdot && gitdot.managed)
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
                stderr.writeln("File ", file,
                        " does neither exist as gitfile nor as dotfile.");
                continue;
            }

            assert(relFile != "");

            write("Please specify the comment indicator for file ",
                    relFile,
                    ": ");
            stdout.flush;
            import std.string : chomp;
            string commentIndicator = readln().chomp();

            if (!gitdot)
            {
                debug logTrace("Add: gitdot does not exist -> Creating");
                assert(!bGitExists); // shouldn't exist if gitdot wasn't found
                gitdot = new GitDot(buildPath(settings.gitdir, relFile),
                                    buildPath(settings.dotdir, relFile));
                bReloadDFM = true;
            }

            gitdot.commentIndicator = commentIndicator;
            gitdot.git.managed = true;
            gitdot.git.write();
            addedGitDots ~= gitdot;
        }

        with (this.dfm)
        {
            string addedFiles;

            foreach (gitdot; addedGitDots)
            {
                git.execute("add", gitdot.git.file);
                addedFiles ~= asRelativePath(gitdot.git.file,
                        settings.gitdir).array ~ "\n";
            }

            commitAndPush("DotfiM Add: \n\n" ~ addedFiles);
        }

        if (bReloadDFM)
            this.dfm.load();

        // Sync dotfiles with new gitHash version
        // and add new dotfiles
        Sync(this.dfm);
    }
}
