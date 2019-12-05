import std.stdio;

import std.file;
import std.algorithm;
import std.path : buildPath;


import dotfim.cmd;
import dotfim.gitdot.passage;


// Add a local line from another mashine to Git and check that it is
// not present in the local dot file of this mashine
void main()
{
    import vibe.core.log;
    setLogLevel(LogLevel.trace);

    string dir = buildPath(tempDir(), "dotfim",
                            "unittest-gitdot-sync-shebang");

    if (dir.exists) dir.rmdirRecurse;

    auto env = Test(dir);

    auto dfm = Init(env).exec;

    auto gitfile = buildPath(dfm.settings.gitdir, ".testshebang");
    auto dotfile = buildPath(dfm.settings.dotdir, ".testshebang");

    File f = File(gitfile, "w");
    f.write("#!/bin/bash\n\n# some lines");
    f.flush();

    f = File(dotfile, "w");
    f.write("#!/bin/bash\n#mylocalline");
    f.flush();

    dfm.load();

    auto add = Add(dfm, gitfile);
    add.commentIndicator = "#";
    add.exec();
    // ERRORS OUT "Shebang is only valid for '#' comment indicator"
}


