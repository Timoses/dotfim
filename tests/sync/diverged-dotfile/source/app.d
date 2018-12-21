import std.stdio;

import std.file;
import std.socket;
import std.algorithm;


import dotfim.gitdot.passage;
import dotfim.cmd;



void main()
{
    string dir = buildPath(tempDir(), "dotfim", "unittest-sync-diverged");

    if (dir.exists) dir.rmdirRecurse;

    auto env = Test(dir);

    auto dfm = Init(env).exec;

    auto gitdot = dfm.gitdots.filter!(gd => gd.dot && gd.git.managed).front;

    Sync(dfm);


    gitdot.git.file.append("Some new line");
    dfm.git.execute("add", gitdot.git.file);
    dfm.git.execute("commit", "-m", "remote commit");
    dfm.git.execute("push", "origin", "dotfim");


    gitdot.dot.passages ~= Passage(Passage.Type.Local, ["my new local line"],
                                    Socket.hostName);

    auto dotpBefore = gitdot.dot.passages;

    Sync(dfm);

    gitdot.dot.load();
    auto dotpAfter = gitdot.dot.passages;

    auto newPassage = dotpAfter.filter!(p => !dotpBefore.canFind(p)).array[0];
    assert(newPassage.type == Passage.Type.Git);
    assert(newPassage.lines == ["Some new line"]);

    gitdot.git.load();
    assert(gitdot.git.passages
            .any!(p => p.type == Passage.Type.Local
                           && p.lines == ["my new local line"]));
}


