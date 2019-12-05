import std.stdio;

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

    auto dotfilePath = buildPath(env.dotdir, ".shebang");
    std.file.write(dotfilePath, "#!/bin/bash\ntestScript");
    Add(dfm, dotfilePath);

    auto gitdot = dfm.findGitDot(dotfilePath);

    assert(dotfilePath.readText().startsWith("#!/bin/bash"));
    assert(gitdot.git.file.readText.startsWith("#!/bin/bash"));
}


