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
        else
        {
            import std.exception : enforce;
            switch (args[0])
            {
                case "add":
                    this.dfUpdater.add(args[1..$]);
                    break;
                case "remove":
                    this.dfUpdater.remove(args[1..$]);
                    break;
                default:
                    break;
            }
        }
    }
}
