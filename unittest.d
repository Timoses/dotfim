#!/usr/bin/env dub
/+ dub.sdl:
    name "Unittest"
+/

import std.algorithm : any, startsWith;
import std.conv : to;
import std.exception : enforce;
import std.file;
import std.path;
import std.stdio : writeln;
void main(string[] args)
{
    enforce(args.length > 1, "Need directory to search for unittest projects");

    string dir = args[1].asAbsolutePath.asNormalizedPath.to!string;
    enforce(dir.exists);

    foreach (cdir; dirEntries(dir, SpanMode.breadth))
    {
        if (!cdir.isDir || cdir.baseName.startsWith("."))
            continue;

        if ([".sdl", ".json"].any!(ext => buildPath(cdir, "dub"~ext).exists))
        {
            writeln("|---------------------------------------");
            writeln("| Running unittest ", asRelativePath(cdir, dir));
            writeln("|---------------------------------------");
            scope(failure)
                writeln("| ----- Failed to run ", asRelativePath(cdir, dir));
            import std.process : spawnProcess, Config, wait;
            auto pid = spawnProcess(["dub", "run", "--build=debug"], null, Config.none, cdir);
            assert(wait(pid) == 0);
        }
    }

    writeln();
    writeln("|--------- All unittests successful ---------|");
}


