module dotfim.cmd;

import dotfim.dotfim;

class CmdHandler
{
    DotfileManager dfUpdater;

    this(DotfileManager dfUpdater)
    {
        this.dfUpdater = dfUpdater;
    }

    void executeCLI(string[] args)
    {
        import std.getopt;

        import std.range : empty;
        if (args.empty)
            this.dfUpdater.update();
    }
}
