
import dotfim.dotfim;
import dotfim.cmd;

void main(string[] args)
{
    // first argument = program name
    import std.file : thisExePath;
    import std.path : buildPath, dirName;
    CmdHandler.executeCLI!DotfileManager(args[1..$],
            buildPath(thisExePath().dirName, "dotfim.json"));
}
