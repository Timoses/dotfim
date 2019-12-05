import std.stdio;

import std.array : array;
import std.file;
import std.socket;
import std.algorithm;
import std.path : buildPath;


import dotfim.gitdot.passage;
import dotfim.cmd;


import vibe.core.log;



void main()
{
    setLogLevel(LogLevel.trace);

    string dir = buildPath(tempDir(), "dotfim", "unittest-sync-diverged");

    if (dir.exists) dir.rmdirRecurse;

    auto env = Test(dir);

    auto dfm = Init(env).exec;

    auto gitdot = dfm.gitdots.filter!(gd => gd.dot && gd.git.managed).front;

    Sync(dfm);


    gitdot.git.file.append("I wanna live!");
    dfm.git.execute("add", gitdot.git.file);
    dfm.git.execute("commit", "-m", "remote commit");
    dfm.git.execute("push", "origin", "dotfim");


    gitdot.dot.passages ~= Passage(Passage.Type.Local, ["I wanna live, too!"],
                                    Socket.hostName);

    auto dotpBefore = gitdot.dot.passages;

    bool resolveMergeConflict()
    {
        gitdot.git.load();
        gitdot.git.passages.each!((ref passage) {
                                    passage.lines = passage.lines.filter!(l => ! ["<<<<<<< HEAD", "=======", ">>>>>>> dotfim"].any!(g => l == g)).array;
                                });
        gitdot.git.write();
        dfm.git.execute(["add", gitdot.git.file]);
        return true;
    }
    dfm.git.mergeConflictHandler = &resolveMergeConflict;
    Sync(dfm, true);

    gitdot.dot.load();
    auto dotpAfter = gitdot.dot.passages;

    auto newPassage = dotpAfter.filter!(p => !dotpBefore.canFind(p)).array[0];
    assert(newPassage.type == Passage.Type.Git);
    assert(newPassage.lines == ["I wanna live!"]);

    gitdot.git.load();
    assert(gitdot.git.passages
            .any!(p => p.type == Passage.Type.Local
                           && p.lines == ["I wanna live, too!"]));
}


