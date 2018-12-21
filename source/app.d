
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
        CmdHandler.executeCLI(args);
    }
}
