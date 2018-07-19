module dotfim.cmd;

import dotfim.dotfim;

import dotfim.cmd.add;
import dotfim.cmd.list;
import dotfim.cmd.remove;
import dotfim.cmd.sync;
import dotfim.cmd.update;
import dotfim.cmd.unsync;

class CmdHandler
{
    static DotfileManager CreateInstance(string settingsFile, DotfileManager.Options options)
    {
        return new DotfileManager(settingsFile, options);
    }

    static void executeCLI(string[] args, string settingsFile)
    {
        auto options = DotfileManager.Options.process(args);
        if (options.bNeededHelp) return;

        // the start index of args to pass to cmd (e.g. add, remove, sync);
        int start = 2;

        if (args.length == 1)
            Update(CreateInstance(settingsFile, options));
        else
        {
            switch (args[1])
            {
                case "add":
                    Add(CreateInstance(settingsFile, options),
                            args[start..$]);
                    break;
                case "list":
                case "ls":
                    List(CreateInstance(settingsFile, options));
                    break;
                case "remove":
                    Remove(CreateInstance(settingsFile, options),
                            args[start..$]);
                    break;
                case "sync":
                    Sync(settingsFile, args[start..$]);
                    break;
                case "unsync":
                    Unsync(CreateInstance(settingsFile, options));
                    break;
                default:
                    import std.exception : enforce;
                    enforce(false, args[1] ~ " is not a valid command. "
                            ~ " See dotfim help.");
                    break;
            }
        }
    }
}
