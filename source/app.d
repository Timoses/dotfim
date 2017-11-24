
import dotfim.dotfim;
import dotfim.cmd;

void main(string[] args)
{
    // first argument = program name
    CmdHandler.executeCLI!DotfileManager(args[1..$], "dotfim.json");
}
