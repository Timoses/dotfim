module dotfim.cmd;

import dotfim.updater;

class CmdHandler
{
    DotfileUpdater dfUpdater;

    this(DotfileUpdater dfUpdater)
    {
        this.dfUpdater = dfUpdater;
    }

    void executeCLI(string[] args)
    {
        import std.stdio;
        int test;
        import std.getopt;


    }
}
