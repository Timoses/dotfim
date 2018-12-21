import std.stdio;

import std.file;
import std.socket;
import std.algorithm;


import dotfim.gitdot.passage;
import dotfim.cmd;
import dotfim.git;
import dotfim.dotfim;


void main()
{
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
    auto afile = env.files.map!(relfile => buildPath(othergitpath, relfile))
                          .find!(file => file.exists).array[0];
    afile.append("a new line");
    otherGit.execute("add", afile);
    otherGit.execute("commit", "-m", "other commit");
    otherGit.execute("push", "origin", "dotfim");

    gitdot.dot.passages ~= Passage(Passage.Type.Local, ["new local line"],
                                   gitdot.settings.localinfo);
    dfm.options.bNoRemote = true;
    Sync(dfm);
    dfm.options.bNoRemote = false;
    // somehow the merge tool file is otherwise included!
    dfm.excludedDots ~= gitdot.relfile ~ ".orig";
    Sync(dfm);


    assert(gitdot.dot.file.readText.canFind("a new line"));
    assert(gitdot.git.file.readText.canFind("new local line"));
}

