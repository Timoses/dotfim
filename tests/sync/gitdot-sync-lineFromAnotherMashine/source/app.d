import std.stdio;

import std.file;
import std.algorithm;


import dotfim.cmd;
import dotfim.gitdot.passage;


// Add a local line from another mashine to Git and check that it is
// not present in the local dot file of this mashine
void main()
{
    string dir = buildPath(tempDir(), "dotfim",
                            "unittest-gitdot-sync-lineFromAnotherMashine");

    if (dir.exists) dir.rmdirRecurse;

    auto env = Test(dir);

    auto dfm = Init(env).exec;

    auto gitdot = dfm.gitdots.filter!(gd => gd.dot && gd.git.managed).front;

    Sync(dfm);

    gitdot.git.passages ~= Passage(Passage.Type.Local, ["another mashine line"], "anotherMashine");
    gitdot.git.write();
    dfm.git.execute("add", gitdot.git.file);
    dfm.git.execute("commit", "-m", "remote commit");
    dfm.git.execute("push", "origin", "dotfim");

    Sync(dfm);

    gitdot.dot.passages.filter!((ref passage)
                                => passage.type == Passage.Type.Private).array[0]
                       .lines[0] ~= "edited";
    assert(gitdot.dot.passages!(Passage.Type.Private)[0].lines[0].endsWith("edited"));

    Sync(dfm);

    assert(gitdot.git.file.readText.canFind("anotherMashine"));
    assert(gitdot.git.file.readText.canFind("another mashine line"));
    assert(!gitdot.dot.file.readText.canFind("anotherMashine"));
    assert(!gitdot.dot.file.readText.canFind("another mashine line"));
}


