import std.stdio;

import std.array : array;
import std.file;
import std.socket;
import std.algorithm;
import std.path : buildPath;


import dotfim.gitdot.passage;
import dotfim.cmd;
import dotfim.git;
import dotfim.dotfim;


void main()
{
    import vibe.core.log;
    setLogLevel(LogLevel.trace);

    string dir = buildPath(tempDir(), "dotfim", "unittest-sync-diverged-branches");
    writeln("Testing in " ~ dir);

    if (dir.exists) dir.rmdirRecurse;

    auto env = Test(dir);

    auto dfm = Init(env).exec;

    auto gitdot = dfm.gitdots.filter!(gd => gd.dot && gd.git.managed).front;

    Sync(dfm);

    // clone into new git and change a file
    string othergitpath = buildPath(dir, "othergit");
    Git.staticExecute(dir, "clone", "--single-branch", "-b",
            DotfileManager.dotfimGitBranch, env.repodir,
            othergitpath);
    auto otherGit = new Git(othergitpath);

    auto afile = buildPath(othergitpath, gitdot.relfile);
    afile.append("I need to survive!");
    otherGit.execute("add", afile);
    otherGit.execute("commit", "-m", "other commit");
    otherGit.execute("push", "origin", "dotfim");

    gitdot.dot.passages ~= Passage(Passage.Type.Local, ["I need to survive as well!"],
                                   gitdot.settings.localinfo);
    dfm.options.bNoRemote = true;
    Sync(dfm);
    dfm.options.bNoRemote = false;
    // somehow the merge tool file is otherwise included!
    dfm.excludedDots ~= gitdot.relfile ~ ".orig";

    bool resolveMergeConflict()
    {
        gitdot.git.load();
        foreach (ref passage; gitdot.git.passages)
        {
            passage.lines = passage.lines.filter!
                                (l => ! ["<<<<<<< HEAD", "=======", ">>>>>>> origin/dotfim"]
                                            .any!(g => l == g)).array;
        }
        gitdot.git.write();
        dfm.git.execute(["add", gitdot.git.file]);
        return true;
    }
    dfm.git.mergeConflictHandler = &resolveMergeConflict;
    Sync(dfm);


    assert(gitdot.dot.file.readText.canFind("I need to survive!"));
    assert(gitdot.git.file.readText.canFind("I need to survive as well!"));
}

