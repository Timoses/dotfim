module dotfim.cmd;

import std.file : getcwd;

import dotfim.dotfim;

public import dotfim.cmd.add;
public import dotfim.cmd.list;
public import dotfim.cmd.remove;
public import dotfim.cmd.init;
public import dotfim.cmd.test;
public import dotfim.cmd.sync;
public import dotfim.cmd.unsync;

class CmdHandler
{
    static string help()
    {
        static string help = q"EOS

Commands:
    init
    add
    remove
    list
    sync
    test
    unsync
EOS";
        return help;

    }

    static DotfileManager CreateInstance(DotfileManager.Options options)
    {
        return new DotfileManager(getcwd(), options);
    }

    static void executeCLI(string[] args)
    {
        auto options = DotfileManager.Options(args);
        if (options.helpWanted) return;

        // the start index of args to pass to cmd (e.g. add, remove, init);
        int start = 1;

        if (args.length == 1)
        {
            options.printHelp();
            return;
        }
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
                    Init(args[start..$]);
                    break;
                case "sync":
                    Sync(CreateInstance(options));
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
