module dotfim.cmd.sync;

import std.exception : enforce;

debug
    import vibe.core.log;

import dotfim.dotfim;
import dotfim.gitdot.gitfile;
import dotfim.gitdot.dotfile;


import std.stdio;

/**
 * Updates the git folder by fetching from and pushing to remote git repository.
 * In case remote and local branches have diverged, merging is attempted.
 * Afterwards, Sync will iterate over all managed git files and check whether
 * the respective dotfiles require an update and whether the dotfiles contain
 * changes that need to be synchronized.
 * If changes to the gitfiles were made these changes are pushed to the remote
 * git repository.
 */
struct Sync
{
    DotfileManager dfm;

    bool autoyes;

    this(lazy DotfileManager dfm, bool autoyes = false)
    {
        this.autoyes = autoyes;
        this.dfm = dfm;

        updateGit();
        exec();
    }

    void updateGit()
    {
        debug logDebug("Sync:updateGit");

        if (!dfm.options.bNoRemote)
        {
            write("... Fetching remote repository ...");
            stdout.flush;
            dfm.git.execute("fetch");
            writeln(" Done");
        }

        string local = dfm.git.hash;
        string remote = dfm.git.remoteHash;
        debug logDebugV("local: %s", local);
        debug logDebugV("remote: %s", remote);

        // remote branch exists and differs
        if (remote.length > 0 && local != remote)
        {
            import std.algorithm : canFind;
            import std.string : chomp;
            string branchBase = dfm.git.execute("merge-base",
                    dfm.dotfimGitBranch,
                    "origin/" ~ dfm.dotfimGitBranch).output.chomp;
            bool bBranchesDiverged = (branchBase != ""
                                        && branchBase != local
                                        && branchBase != remote)
                                     ? true : false;

            // Second: If branches had diverged, merge them back together
            if (bBranchesDiverged)
            {
                debug logTrace("Sync:updateGit | branches diverged, branch base: %s",
                                branchBase);

                writeln("... Branches diverged! Attempting merge ...");

                immutable string mergeBranchName = "merge-" ~ dfm.dotfimGitBranch;
                scope(failure)
                {
                    dfm.git.execute(["checkout", dfm.dotfimGitBranch]);
                    dfm.git.execute("branch", "-D", mergeBranchName);
                }
                // commit dotfiles to merge branch
                dfm.git.execute(["checkout", "-b",
                                    mergeBranchName,
                                    dfm.dotfimGitBranch]);

                if (dfm.git.merge(mergeBranchName
                            , "origin/" ~ dfm.dotfimGitBranch))
                {
                    // take over merged branch
                    dfm.git.execute("rebase", mergeBranchName, dfm.dotfimGitBranch);
                    dfm.git.execute("branch", "-d", mergeBranchName);
                }
                else
                {
                    throw new Exception("Merge failed... Aborted dotfim sync!");
                }

                dfm.load();
            }

            // remote branch is ahead -> checkout remote
            if (!dfm.git.execute("branch", "-a", "--contains", remote)
                    .output.canFind("* dotfim"))
            {
                write("... Rebasing to remote repository ...");
                stdout.flush;
                dfm.git.execute("rebase", "origin/" ~ dfm.dotfimGitBranch);
                writeln("Rebased to remote branch: ", remote[0..6]);
                dfm.load();
            }
            // else: local is ahead of remote?
            else if (!dfm.options.bNoRemote
                    && !dfm.git.execute("branch", "--contains", local).output
                        .canFind("origin/dotfim"))
            {
                write("... Pushing to remote repository ...");
                stdout.flush;
                dfm.git.push(dfm.dotfimGitBranch);
                writeln(" Done");
            }
        }
        else if (remote.length == 0) // remote git branch does not exist
        {
            dfm.git.push(dfm.dotfimGitBranch);
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
        import std.algorithm : canFind, each, map, uniq, filter;
        import std.array : join;
        import std.conv : to;
        import std.file : exists;
        import std.format : format;
        import std.path : asRelativePath;
        import std.range : array, drop;
        import std.string : join, splitLines, chomp, split;

        import dotfim.gitdot;
        import dotfim.util : askContinue;

        debug logDebug("Sync:exec");

        with(this.dfm)
        {
            struct GitHash
            {
                private string _hash;
                void set(string hash) {
                    _hash = hash;
                    gitdots.each!(gitdot => gitdot.git.hash = _hash); }

                void opAssign(string hash) { set(hash); }
                string opCall() { return _hash; }

                bool opEquals(string other)
                {
                    return _hash == other;
                }
            }
            GitHash curhash;

            curhash = git.hash;

            enforce(git.remoteHash == git.hash, "Git is not updated correctly, "
                    ~ "remote and local hash differ!\nlocal: %s\n remote: %s"
                    .format(git.hash, git.remoteHash));

            GitDot[] dfUpdatees;
            GitDot[] gfUpdatees;
            GitDot[] divergees;

            // 1: Collect files that need update
            foreach (gitdot; gitdots)
            {

                debug logTrace("Sync.1: Checking gitdot " ~ gitdot.git.file);

                if (gitdot.git.managed && !gitdot.dot.managed)
                {
                    // update dotfile to be managed
                    dfUpdatees = uniq(dfUpdatees ~ gitdot).array;

                    // update gitfile in case unmanaged dotfile
                    // contains local lines
                    if (gitdot.dot.file.exists)
                    {
                        gfUpdatees = uniq(gfUpdatees ~ gitdot).array;
                        debug logTrace("Sync.1: Dotfile not managed");
                    }
                    else
                        debug logTrace("Sync.1: Dotfile doesn't exist");
                }
                else if (gitdot.git.managed)
                {
                    string dothash = gitdot.dot.hash;
                    enforce(dothash != "", "Hash of managed dotfile can not be empty");
                    if (dothash != curhash)
                    {
                        debug logTrace("Sync.1: Dot hash and git hash differ");

                        // dotfile will require rewrite
                        dfUpdatees ~= gitdot;

                        // get content of old git file
                        scope(exit) git.execute("checkout", dotfimGitBranch);
                        git.execute("checkout", dothash);

                        auto oldgit = new Gitfile(gitdot.settings, gitdot.git.file);
                        oldgit.load();

                        if (oldgit != gitdot.dot)
                        {
                            debug logTrace("Sync.1: Dot content or file mode differs as well!");
                            divergees = uniq(divergees ~ gitdot).array;
                        }
                    }
                    else // same git hash
                    {
                        debug string logentry = "Sync.1: Git and Dot hash are equal ... ";
                        // updates/changes in dotfile?
                        if (gitdot.dot != gitdot.git)
                        {
                            debug logTrace(logentry ~ "Dotfile updated");
                            gfUpdatees = uniq(gfUpdatees ~ gitdot).array;
                        }
                        else
                            debug logTrace(logentry ~ "Equal Dot- and Gitfile");
                    }
                }
                else if (!gitdot.git.managed)
                    debug logTrace("Sync.1: Gitfile not managed");
            }

            debug {
                logDebugV("Sync.1-CollectFiles | dfUpdatees: %s, "
                            ~ " | gfUpdatees: %s | divergees: %s"
                            , dfUpdatees.map!((d) => d.relfile)
                            , gfUpdatees.map!((g) => g.relfile)
                            , divergees.map!((d) => d.relfile));
            }


            // 2: Merge
            if (divergees.length > 0)
            {
                if (!autoyes && !askContinue("The following files have diverged:\n"
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
                string commonBaseHash = divergees[0].dot.hash;
                foreach (gitdot; divergees)
                {
                    enforce(gitdot.dot.hash == commonBaseHash,
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
                    // Need to load the old git file as to
                    // not commit changes from other machine's
                    // local/private passages
                    auto oldgit = new Gitfile(gitdot.settings, gitdot.git.file);
                    oldgit.load();
                    auto curgit = gitdot.git;
                    scope(exit) gitdot.git = curgit;
                    gitdot.git = oldgit;
                    gitdot.syncTo!Gitfile();
                    gitdot.git.write();
                    git.execute("add", gitdot.git.file);
                }
                // commit these changes
                git.execute(["commit", "-m", "Diverged commit"]);

                // Try merging
                if (git.merge(mergeBranchName, dotfimGitBranch)
                    && (this.autoyes || askContinue("The merge appears successful.\n" ~
                            "Would you like to take over the changes? (y/n): ",
                            "y")))
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

                    curhash = git.hash;

                    // read merged contents from gitfiles
                    foreach (gitdot; divergees)
                        gitdot.git.load();
                }
                else
                {
                    throw new Exception("Merge failed... Aborted dotfim sync!");
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
                        debug logTrace("Sync.3: Updating gitfile %s", gitdot.relfile);

                        if (gitdot.syncTo!Gitfile())
                        {
                            gitdot.git.write();
                            git.execute("add", gitdot.git.file);
                            changedFiles ~= asRelativePath(gitdot.git.file,
                                                settings.gitdir).to!string
                                            ~ "\n";
                        }
                    }

                    if (changedFiles.length)
                    {
                        changedFiles = changedFiles.chomp;

                        commitAndPush("DotfiM Sync" ~
                                    " (" ~ this.dfm.settings.localinfo ~ ")" ~
                                    ": \n\n" ~ changedFiles);
                    }
                }
                catch (Exception e)
                {
                    stderr.writeln(e.msg);
                    git.execute(["reset", "--hard"]);
                    stderr.writeln("Error occured while updating the git repository. Please fix issues and try again.");
                    stderr.writeln("Stopping sync.");
                    load();
                    return;
                }

                scope(success)
                {
                    if (changedFiles.length)
                    {
                        curhash = git.hash;
                        writeln("Git repo files synced:");
                        writeln(changedFiles
                                .splitLines
                                .map!((e) => "\t" ~ e)
                                .join("\n"));
                    }
                }
            }


            // 4: Update dotfiles
            // if commits done or if oldGitHash found
            if (gfUpdatees.length == 0
                    && dfUpdatees.length == 0
                    && divergees.length == 0)
            {
                writeln("Everything's already up to date");
            }
            else if (gfUpdatees.length > 0 || dfUpdatees.length > 0)
            {
                writeln("Dotfiles synced:");

                void dfUpdate(GitDot[] dfs)
                {
                    // Only git hashs will be updated
                    if (dfUpdatees.length == 0)
                        writeln("\tNone");

                    foreach (gitdot; dfs)
                    {
                        debug logTrace("Sync.4: Updating dotfile %s", gitdot.relfile);

                        if (gitdot.syncTo!Dotfile())
                            gitdot.dot.write();

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
                    dfUpdate(gitdots.filter!(gd => gd.managed).array);
                }
                else
                    dfUpdate(dfUpdatees);
            }
        }
    }
}

version(unittest_all) unittest
{
    import std.file : tempDir, exists, rmdirRecurse;
    import std.path : buildPath;
    import std.stdio;
    import dotfim.cmd : Add, Init, Test;
    import dotfim.gitdot.passage;

    string testpath = buildPath(tempDir(), "dotfim", "unittest-sync-add");
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
        // Need to use '#' for commentIndicator!
        auto add = Add(dfm, testfile);
        add.commentIndicator = "#";
        add.exec();
        mixin(checkHash);
        auto gitdot = dfm.findGitDot(testfile);
        assert(gitdot);

        // write entry
        enum string testentry = "This is a test entry to be synced.";
        auto dfile = gitdot.dot;
        dfile.passages ~= Passage(Passage.Type.Git, [testentry]);
        dfile.write;
        Sync(dfm);
        mixin(checkHash);
    }
    auto dfm = new DotfileManager(testenv.gitdir);
    assert(dfm.gitdots.length == 3);
    auto gitdot = dfm.findGitDot(testfile);
    assert(gitdot);
    assert(gitdot.dot.passages!(Passage.Type.Git) == gitdot.git.passages!(Passage.Type.Git));
    assert(gitdot.dot.hash == dfm.git.hash);
}

// Test if a line is synced correctly between two mashines
version(unittest_all) unittest
{
    import std.algorithm : each;
    import std.conv : to;
    import std.file;
    import std.path : buildPath, asRelativePath;
    import std.stdio;
    import dotfim.cmd : Test, Init, Sync;
    import dotfim.gitdot.passage;

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
    dot1.passages ~= Passage(Passage.Type.Local, [testline], dot1.settings.localinfo);
    dot1.write;
    Sync(dfm1);
    Sync(dfm2);
    auto gitdot2 = dfm2.findGitDot(asRelativePath(dot1.file, dfm1.settings.dotdir).to!string);
    assert(gitdot2.dot.passages!(Passage.Type.Local)[$-1].lines == [testline]);
}
