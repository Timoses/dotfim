module dotfim.cmd.update;

import dotfim.dotfim;

struct Update
{
    DotfileManager dfm;
    this(lazy DotfileManager dfm)
    {
        this.dfm = dfm;

        exec();
    }

    /**
     * Update:
     *  Update will proceed as follows:
     *   1. Collect files:
     *        - dfUpdatees: remote update available for dotfile
     *              local git hash != remote git hash
     *              && locally no changes were applied to dotfile
     *        - gfUpdatees: local update available for gitfile
     *              local git hash == remote git hash
     *        - divergees: local and remote changes! requires merge!
     *              local git hash != remote git hash
     *              && local changes were applied to dotfile
     *   2. Merge divergees:
     *        Dotfiles:
     *           no actions
     *        Gitfiles:
     *           Creates "merge" branch based on common base commit,
     *           commits local changes (dotfiles
     *           content) to it and merges it with remote branch.
     *           Successful: Apply merged branch as new base branch
     *              -> NEW GIT HASH -> all dotfiles require update
     *           Unsuccessful: Abort! Delete "merge" branch.
     *   3. Update gitfiles gfUpdatees
     *        Copy content of updated dotfiles to gitfiles
     *        and commit.
     *              -> NEW GIT HASH -> all dotfiles require update
     *        Note: gfUpdatees should be empty when merge was required
     *              since in that case remote and local git hash differed.
     *   4. Update dotfiles:
     *      If git hashs differed write all changes to dotfiles (also
     *      updating dotfile hashes)
     *
     */
    private void exec()
    {
        with(this.dfm)
        {
            string curGitHash = git.hash;

            import dotfim.gitdot;
            import dotfim.util : askContinue;

            GitDot[] dfUpdatees;
            GitDot[] gfUpdatees;
            GitDot[] divergees;

            import std.string : chomp;
            string branchBase = git.execute("merge-base",
                    dotfimGitBranch,
                    "origin/" ~ dotfimGitBranch).output.chomp;
            bool bBranchesDiverged;
            if (branchBase != ""
                        && branchBase != curGitHash
                        && branchBase != git.remoteHash)
                bBranchesDiverged = true;

            // 1: Collect files that need update
            foreach (gitdot; gitdots)
            {
                if (!gitdot.dotfile.managed)
                {
                    import std.algorithm : uniq;
                    import std.array;
                    dfUpdatees = uniq(dfUpdatees ~ gitdot).array;
                }
                else
                {
                    string dotGitHash = gitdot.dotfile.gitHash;
                    import std.exception : enforce;
                    enforce(dotGitHash != "", "dotfile's Git Section commit hash can not be empty");
                    if (dotGitHash != curGitHash)
                    {
                        // dotfile will require rewrite
                        dfUpdatees ~= gitdot;

                        // get content of old git file
                        import std.path : asRelativePath;
                        import std.conv : to;
                        string relGitPath = asRelativePath(
                                gitdot.gitfile.file,
                                settings.gitPath).to!string;
                        import std.string : splitLines;
                        import std.range : drop;
                        string[] oldGitLines =
                            git.execute("show",
                                dotGitHash ~ ":" ~ relGitPath).output
                                .splitLines()
                                .drop(1); // drop header line

                        // and check for custom updates
                        if (oldGitLines != gitdot.dotfile.gitLines)
                        {
                            import std.algorithm : uniq;
                            import std.array;
                            divergees = uniq(divergees ~ gitdot).array;
                        }
                    }
                    else // same git hash
                    {
                        // updates/changes in dotfile?
                        if (gitdot.dotfile.gitLines != gitdot.gitfile.gitLines)
                        {
                            import std.algorithm : uniq;
                            import std.array;
                            gfUpdatees = uniq(gfUpdatees ~ gitdot).array;
                        }
                    }
                }
            }

            // 2: Merge
            if (bBranchesDiverged || divergees.length > 0)
            {
                import std.algorithm : map;
                import std.array : join;
                import std.conv : to;
                // First: merge diverged dotfiles into dotfimBranch
                if (divergees.length)
                {
                    import std.path : asRelativePath;
                    if (!askContinue("The following files have diverged:\n"
                            ~ divergees.map!((e) => asRelativePath(
                                    e.gitfile.file,
                                    settings.gitPath).to!string)
                                .join("\n")
                            ~ "\nWould you like to attempt merging? (y/n): ", "y"))
                        // stop!
                        throw new Exception("User aborted merge!");

                    // common base commit should be dotfile hash
                    // TODO: support multiple different dotfile hashes
                    //       (however that might happen) -> multiple merge
                    //       branches and merge commits
                    string commonBaseHash = divergees[0].dotfile.gitHash;
                    foreach (gitdot; divergees)
                    {
                        import std.exception : enforce;
                        enforce(gitdot.dotfile.gitHash == commonBaseHash,
                                "Found differing git hashes in divergent "
                                ~ "dotfiles. Currently only one merge base "
                                ~ "base is supported! Aborting Merge.");
                    }

                    immutable string mergeBranchName = "merge-"
                        ~ dotfimGitBranch;
                    scope(failure)
                    {
                        git.execute(["checkout", dotfimGitBranch]);
                        git.execute("branch", "-D", mergeBranchName);
                    }
                    // commit dotfiles to merge branch
                    git.execute(["checkout", "-b",
                                        mergeBranchName,
                                        commonBaseHash]);
                    // write dotfiles updates to gitfiles
                    foreach (gitdot; divergees)
                    {
                        gitdot.gitfile.gitLines = gitdot.dotfile.gitLines;
                        gitdot.gitfile.write();
                        git.execute("add", gitdot.gitfile.file);
                    }
                    // commit these changes
                    git.execute(["commit", "-m", "Diverged commit"]);

                    // Try merging
                    if (git.merge(mergeBranchName, dotfimGitBranch)
                        && askContinue("The merge appears successful.\n" ~
                                "Would you like to take over the changes? (y/n): ",
                                "y"))
                    {
                        // take over merged branch
                        git.execute("rebase", mergeBranchName, dotfimGitBranch);
                        git.execute("branch", "-d", mergeBranchName);

                        string mergedFiles;
                        foreach (div; divergees)
                        {
                            mergedFiles ~= asRelativePath(div.gitfile.file,
                                            settings.gitPath).to!string
                                        ~ "\n";
                        }
                        // update commit message (ammend)
                        git.commit("Merged update\n\n" ~ mergedFiles,
                                            true);

                        curGitHash = git.hash;

                        // read merged contents from gitfiles
                        foreach (gitdot; divergees)
                            gitdot.gitfile.read();
                    }
                    else
                    {
                        throw new Exception("Merge failed... Aborted dotfim update!");
                    }
                }
                // Second: If branches had diverged, merge them back together
                if (bBranchesDiverged)
                {
                    immutable string mergeBranchName = "merge-" ~ dotfimGitBranch;
                    scope(failure)
                    {
                        git.execute(["checkout", dotfimGitBranch]);
                        git.execute("branch", "-D", mergeBranchName);
                    }
                    // commit dotfiles to merge branch
                    git.execute(["checkout", "-b",
                                        mergeBranchName,
                                        dotfimGitBranch]);

                    if (git.merge(mergeBranchName
                                , "origin/" ~ dotfimGitBranch))
                    {
                        // take over merged branch
                        git.execute("rebase", mergeBranchName, dotfimGitBranch);
                        git.execute("branch", "-d", mergeBranchName);

                        curGitHash = git.hash;

                        // read new gitfile contents
                        foreach (gitdot; gitdots)
                            gitdot.gitfile.read();
                    }
                    else
                    {
                        throw new Exception("Merge failed... Aborted dotfim update!");
                    }
                }
            }

            // 3: Commit changes to gitfiles, if any
            if (gfUpdatees.length > 0)
            {
                string changedFiles;
                try
                {
                    foreach (gitdot; gfUpdatees)
                    {
                        gitdot.gitfile.gitLines = gitdot.dotfile.gitLines;
                        gitdot.gitfile.write();
                        git.execute("add", gitdot.gitfile.file);
                        import std.conv : to;
                        import std.path : asRelativePath;
                        changedFiles ~= asRelativePath(gitdot.gitfile.file,
                                            settings.gitPath).to!string
                                        ~ "\n";
                    }

                    import std.string : chomp;
                    changedFiles = changedFiles.chomp;

                    commitAndPush("DotfiM Update: \n\n" ~ changedFiles);
                }
                catch (Exception e)
                {
                    import std.stdio : writeln;
                    writeln(e.msg);
                    git.execute(["reset", "--hard"]);
                    writeln("Error occured while updating the git repository. Please fix issues and try again.");
                    writeln("Stopping update.");
                    return;
                }

                scope(success)
                {
                    import std.stdio : writeln;
                    curGitHash = git.hash;
                    writeln("Git repo files updated:");
                    import std.algorithm : map;
                    import std.string : splitLines, join;
                    writeln(changedFiles
                            .splitLines
                            .map!((e) => "\t" ~ e)
                            .join("\n"));
                }
            }

            // 4: Update dotfiles
            // if commits done or if oldGitHash found
            if (gfUpdatees.length == 0
                    && dfUpdatees.length == 0
                    && divergees.length == 0)
            {
                import std.stdio : writeln;
                writeln("Everything's already up to date");
            }
            else if (gfUpdatees.length > 0 || dfUpdatees.length > 0)
            {
                import std.stdio : writeln;
                writeln("Dotfiles updated:");

                void dfUpdate(GitDot[] dfs)
                {
                    // Only git hashs will be updated
                    if (dfUpdatees.length == 0)
                        writeln("\tNone");

                    foreach (gitdot; dfs)
                    {
                        gitdot.dotfile.gitLines = gitdot.gitfile.gitLines;
                        gitdot.dotfile.gitHash = curGitHash;
                        gitdot.dotfile.write();

                        import std.algorithm : canFind;
                        import std.conv : to;
                        import std.path : asRelativePath;
                        // tell user if a dotfile's contents actually changed
                        if (dfUpdatees.canFind(gitdot))
                            writeln("\t" ~
                                asRelativePath(gitdot.dotfile.file,
                                    settings.dotPath).to!string);
                    }
                }

                // new git hash -> update all dotfiles in order
                // to renew their hashes
                if (gfUpdatees.length > 0 || divergees.length > 0)
                {
                    dfUpdate(gitdots);
                }
                else
                    dfUpdate(dfUpdatees);
            }
        }
    }
}

unittest
{
    import std.stdio;
    import dotfim.util.test;
    import dotfim.cmd : Add, Sync;

    string oldGitHash;
    enum string checkHash = q{
        assert(oldGitHash != dfm.git.hash, "Hash was not updated");
        oldGitHash = dfm.git.hash;
        };
    {
        auto dfm = prepareExample();
        Update(dfm);
        oldGitHash = dfm.git.hash;
        assert(dfm.gitdots.length == 0);
        Add(dfm, testfile);
        mixin(checkHash);
        auto gitdot = dfm.findGitDot(testfile);
        assert(gitdot);

        // write entry
        enum string testentry = "This is a test entry to be updated.";
        auto dfile = gitdot.dotfile;
        dfile.gitLines = dfile.gitLines ~ testentry;
        dfile.write;
        Update(dfm);
        mixin(checkHash);
    }
    auto dfm = new DotfileManager(settingsfile);
    assert(dfm.gitdots.length == 1);
    auto gitdot = dfm.findGitDot(testfile);
    assert(gitdot);
    assert(gitdot.dotfile.gitLines == gitdot.gitfile.gitLines);
    assert(gitdot.dotfile.gitHash == dfm.git.hash);
}
