module dotfim.cmd;

import dotfim.dotfim;

class CmdHandler
{
    static T CreateInstance(T)(string settingsFile, T.Options options)
    {
        return new T(settingsFile, options);
    }

    static void executeCLI(T)(string[] args, string settingsFile)
    {
        auto options = T.Options.process(args);
        if (options.bNeededHelp) return;

        // the start index of args to pass to sub (e.g. add, remove, sync);
        int start = 2;

        if (args.length == 1)
            CreateInstance!T(settingsFile, options).update();
        else
        {
            switch (args[1])
            {
                case "add":
                    CreateInstance!T(settingsFile, options).add(args[start..$]);
                    break;
                case "remove":
                    CreateInstance!T(settingsFile, options).remove(args[start..$]);
                    break;
                case "sync":
                    auto inst = T.sync(args[start..$], settingsFile);
                    if (inst) inst.update();
                    break;
                default:
                    CreateInstance!T(settingsFile, options).update();
                    break;
            }
        }
    }
}
