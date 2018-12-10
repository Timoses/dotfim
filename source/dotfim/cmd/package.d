module dotfim.cmd;

import std.file : getcwd;

import dotfim.dotfim;

public import dotfim.cmd.add;
public import dotfim.cmd.list;
public import dotfim.cmd.remove;
public import dotfim.cmd.init;
public import dotfim.cmd.test;
public import dotfim.cmd.update;
public import dotfim.cmd.unsync;

class CmdHandler
{
    static DotfileManager CreateInstance(DotfileManager.Options options)
    {
        return new DotfileManager(getcwd(), options);
    }

    static void executeCLI(string[] args)
    {
        auto options = DotfileManager.Options.process(args);
        if (options.bNeededHelp) return;

        // the start index of args to pass to cmd (e.g. add, remove, init);
        int start = 2;

        if (args.length == 1)
            Update(CreateInstance(options));
        else
        {
            switch (args[1])
            {
                case "add":
                    Add(CreateInstance(options),
                            args[start..$]);
                    break;
                case "list":
                case "ls":
                    List(CreateInstance(options));
                    break;
                case "remove":
                    Remove(CreateInstance(options),
                            args[start..$]);
                    break;
                case "init":
                    Init(getcwd(), args[start..$]);
                    break;
                case "unsync":
                    Unsync(CreateInstance(options));
                    break;
                case "test":
                    Test(args[start..$]);
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
