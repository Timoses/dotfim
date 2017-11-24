module dotfim.cmd;

import dotfim.dotfim;

class CmdHandler
{
    static T CreateInstance(T)(string settingsFile)
    {
        return new T(settingsFile);
    }

    static void executeCLI(T)(string[] args, string settingsFile)
    {
        import std.getopt;

        import std.range : empty;
        if (args.empty)
            CreateInstance!T(settingsFile).update();
        else
        {
            import std.exception : enforce;
            switch (args[0])
            {
                case "add":
                    CreateInstance!T(settingsFile).add(args[1..$]);
                    break;
                case "remove":
                    CreateInstance!T(settingsFile).remove(args[1..$]);
                    break;
                case "sync":
                    auto inst = T.sync(args[1..$], settingsFile);
                    if (inst) inst.update();
                    break;
                default:
                    break;
            }
        }
    }
}
