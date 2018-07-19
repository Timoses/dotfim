
import dotfim.dotfim;
import dotfim.cmd;

void main(string[] args)
{
    import std.file : thisExePath;
    import std.path : buildPath, dirName;
    CmdHandler.executeCLI(args,
            buildPath(thisExePath().dirName, "dotfim.json"));
}
