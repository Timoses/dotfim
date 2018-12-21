
import dotfim.dotfim;
import dotfim.cmd;

debug shared static this()
{
    import vibe.core.log;
    setLogLevel(LogLevel.trace);
}

version(unittest){}
else
{
    void main(string[] args)
    {
        try CmdHandler.executeCLI(args);
        catch (Exception e)
        {
            import std.stdio;
            stderr.writeln(e.msg);
            debug throw e;
        }

    }
}
