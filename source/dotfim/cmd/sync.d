module dotfim.cmd.sync;

debug
    import vibe.core.log;

import dotfim.dotfim;

struct Sync
{
    DotfileManager dfm;
    this(lazy DotfileManager dfm)
    {
        this.dfm = dfm;

        updateGit();
        exec();
    }

    void updateGit()
    {
        debug logDebug("Sync:updateGit");

        import std.stdio : writeln;
        if (!dfm.options.bNoRemote)
        {
            writeln("... Fetching remote repository ...");
            dfm.git.execute("fetch");
        }

        string local = dfm.git.hash;
        string remote = dfm.git.remoteHash;
        writeln("local: ", local);
        writeln("remote: ", remote);

        // remote branch exists and differs
        if (remote.length > 0 && local != remote)
        {
            import std.algorithm : canFind;
            // remote branch is ahead -> checkout remote
            if (!dfm.git.execute("branch", "-a", "--contains", remote)
                    .output.canFind("* dotfim"))
            {
                writeln("... Rebasing to remote repository ...");
                dfm.git.execute("rebase", "origin/" ~ dfm.dotfimGitBranch);
                writeln("Rebased to remote branch: ", remote[0..6]);
                dfm.load();
            }

            // else: local is ahead of remote?
            if (!dfm.options.bNoRemote
                    && !dfm.git.execute("branch", "--contains", local).output
                        .canFind("origin/dotfim"))
            {
                writeln("... Pushing to remote repository ...");
                dfm.git.push(dfm.dotfimGitBranch);
            }
        }
    }

    /**
     * Sync:
     *  Sync will proceed as follows:
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
        debug logDebug("Sync:exec");
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
                if (!gitdot.dot.managed)
                {
                    import std.algorithm : uniq;
                    import std.array;
                    dfUpdatees = uniq(dfUpdatees ~ gitdot).array;
                }
                else
                {
                    string dotGitHash = gitdot.dot.gitHash;
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
                                gitdot.git.file,
                                settings.gitdir).to!string;
                        import std.string : splitLines;
                        import std.range : drop;
                        string[] oldGitLines =
                            git.execute("show",
                                dotGitHash ~ ":" ~ relGitPath).output
                                .splitLines()
                                .drop(1); // drop header line

                        // and check for custom updates
                        if (oldGitLines != gitdot.dot.gitLines)
                        {
                            import std.algorithm : uniq;
                            import std.array;
                            divergees = uniq(divergees ~ gitdot).array;
                        }
                    }
                    else // same git hash
                    {
                        // updates/changes in dotfile?
                        if (gitdot.dot.gitLines != gitdot.git.gitLines)
                        {
                            import std.algorithm : uniq;
                            import std.array;
                            gfUpdatees = uniq(gfUpdatees ~ gitdot).array;
                        }
                    }
                }
            }

            debug {
                import std.algorithm : map;
                logDebugV("Sync.1-CollectFiles | dfUpdatees: %s, "
                            ~ " | gfUpdatees: %s | divergees: %s"
                            , dfUpdatees.map!((d) => d.dot.file)
                            , gfUpdatees.map!((g) => g.git.file)
                            , divergees.map!((d) => d.dot.file));
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
                                    e.git.file,
                                    settings.gitdir).to!string)
                                .join("\n")
                            ~ "\nWould you like to attempt merging? (y/n): ", "y"))
                        // stop!
                        throw new Exception("User aborted merge!");

                    // common base commit should be dotfile hash
                    // TODO: support multiple different dotfile hashes
                    //       (however that might happen) -> multiple merge
                    //       branches and merge commits
                    string commonBaseHash = divergees[0].dot.gitHash;
                    foreach (gitdot; divergees)
                    {
                        import std.exception : enforce;
                        enforce(gitdot.dot.gitHash == commonBaseHash,
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
                        gitdot.git.gitLines = gitdot.dot.gitLines;
                        gitdot.git.write();
                        git.execute("add", gitdot.git.file);
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
                            mergedFiles ~= asRelativePath(div.git.file,
                                            settings.gitdir).to!string
                                        ~ "\n";
                        }
                        // update commit message (ammend)
                        git.commit("Merged update\n\n" ~ mergedFiles,
                                            true);

                        curGitHash = git.hash;

                        // read merged contents from gitfiles
                        foreach (gitdot; divergees)
                            gitdot.git.read();
                    }
                    else
                    {
                        throw new Exception("Merge failed... Aborted dotfim sync!");
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
                            gitdot.git.read();
                    }
                    else
                    {
                        throw new Exception("Merge failed... Aborted dotfim sync!");
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
                        gitdot.git.gitLines = gitdot.dot.gitLines;
                        gitdot.git.write();
                        git.execute("add", gitdot.git.file);
                        import std.conv : to;
                        import std.path : asRelativePath;
                        changedFiles ~= asRelativePath(gitdot.git.file,
                                            settings.gitdir).to!string
                                        ~ "\n";
                    }

                    import std.string : chomp;
                    changedFiles = changedFiles.chomp;

                    commitAndPush("DotfiM Sync: \n\n" ~ changedFiles);
                }
                catch (Exception e)
                {
                    import std.stdio : writeln;
                    writeln(e.msg);
                    git.execute(["reset", "--hard"]);
                    writeln("Error occured while updating the git repository. Please fix issues and try again.");
                    writeln("Stopping sync.");
                    return;
                }

                scope(success)
                {
                    import std.stdio : writeln;
                    curGitHash = git.hash;
                    writeln("Git repo files synced:");
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
                writeln("Dotfiles synced:");

                void dfUpdate(GitDot[] dfs)
                {
                    // Only git hashs will be updated
                    if (dfUpdatees.length == 0)
                        writeln("\tNone");

                    foreach (gitdot; dfs)
                    {
                        gitdot.dot.gitLines = gitdot.git.gitLines;
                        gitdot.dot.gitHash = curGitHash;
                        gitdot.dot.write();

                        import std.algorithm : canFind;
                        import std.conv : to;
                        import std.path : asRelativePath;
                        // tell user if a dotfile's contents actually changed
                        if (dfUpdatees.canFind(gitdot))
                            writeln("\t" ~
                                asRelativePath(gitdot.dot.file,
                                    settings.dotdir).to!string);
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
    import std.file : tempDir, exists, rmdirRecurse;
    import std.path : buildPath;
    import std.stdio;
    import dotfim.cmd : Add, Init, Test;

    string testpath = buildPath(tempDir(), "dotfim", "unittest-add");
    if (testpath.exists) testpath.rmdirRecurse;
    string oldGitHash;
    auto testenv = Test(testpath);
    auto testfile = buildPath(testenv.options.dotdir, ".file3");

    enum string checkHash = q{
        assert(oldGitHash != dfm.git.hash, "Hash was not updated");
        oldGitHash = dfm.git.hash;
        };

    {
        auto dfm = Init(testenv).exec();

        Sync(dfm);
        oldGitHash = dfm.git.hash;
        assert(dfm.gitdots.length == 2);
        Add(dfm, testfile);
        mixin(checkHash);
        auto gitdot = dfm.findGitDot(testfile);
        assert(gitdot);

        // write entry
        enum string testentry = "This is a test entry to be synced.";
        auto dfile = gitdot.dot;
        dfile.gitLines = dfile.gitLines ~ testentry;
        dfile.write;
        Sync(dfm);
        mixin(checkHash);
    }
    auto dfm = new DotfileManager(testenv.gitdir);
    assert(dfm.gitdots.length == 3);
    auto gitdot = dfm.findGitDot(testfile);
    assert(gitdot);
    assert(gitdot.dot.gitLines == gitdot.git.gitLines);
    assert(gitdot.dot.gitHash == dfm.git.hash);
}

// Test if a line is synced correctly between two mashines
unittest
{
    import std.algorithm : each;
    import std.conv : to;
    import std.file : tempDir, rmdirRecurse, exists;
    import std.path : buildPath, asRelativePath;
    import std.stdio;
    import dotfim.cmd : Test, Init, Sync;

    enum string testline = "This is a test line to be synced";

    string testdir1 = buildPath(tempDir(), "dotfim", "unittest-sync", "env1");
    string testdir2 = buildPath(tempDir(), "dotfim", "unittest-sync", "env2");
    [testdir1, testdir2].each!((dir) => dir.exists ? dir.rmdirRecurse : {});
    auto testenv1 = Test(testdir1);
    auto testenv2 = Test(testdir2);
    string repodir = testenv1.repodir;

    auto dfm1 = Init(testenv1).exec();
    auto init2 = Init(testenv2);
    init2.repodir = testenv1.repodir;
    auto dfm2 = init2.exec();

    Sync(dfm1);
    Sync(dfm2);

    auto dot1 = dfm1.gitdots[0].dot;
    dot1.gitLines = dot1.gitLines ~ testline;
    dot1.write;
    Sync(dfm1);
    Sync(dfm2);
    auto gitdot2 = dfm2.findGitDot(asRelativePath(dot1.file, dfm1.settings.dotdir).to!string);
    assert(gitdot2.dot.gitLines[$-1] == testline);
}
