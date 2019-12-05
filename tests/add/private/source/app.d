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

    string dir = buildPath(tempDir(), "dotfim", "unittest-add-private");

    if (dir.exists) dir.rmdirRecurse;

    auto env = Test(dir);

    auto dfm = Init(env).exec;

    Sync(dfm);

    Add(dfm, buildPath(env.dotdir, ".file3"));

    auto gitdot = dfm.findGitDot(".file3");

    gitdot.git.file.append("I need to live!");
    dfm.git.execute("add", gitdot.git.file);
    dfm.git.execute("commit", "-m", "remote commit");
    dfm.git.execute("push", "origin", "dotfim");


    gitdot.dot.passages ~= Passage(Passage.Type.Local, ["I need to live, too!"],
                                    Socket.hostName);

    auto dotpBefore = gitdot.dot.passages;

    Sync(dfm);

    gitdot.dot.load();
    auto dotpAfter = gitdot.dot.passages;

    auto newPassage = dotpAfter.filter!(p => !dotpBefore.canFind(p)).array[0];
    assert(newPassage.type == Passage.Type.Git);
    assert(newPassage.lines == ["I need to live!"]);

    gitdot.git.load();
    assert(gitdot.git.passages
            .any!(p => p.type == Passage.Type.Local
                           && p.lines == ["I need to live, too!"]));
}


