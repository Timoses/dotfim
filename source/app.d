
import dotfim.dotfim;
import dotfim.cmd;

void main(string[] args)
{
    import std.stdio;
    import std.json;
    import std.file;
    auto settings = parseJSON(readText("settings.json"));

    auto upd = new DotfileManager(settings["dotfilesRepository"].str);
    auto cmd = new CmdHandler(upd);

    // first argument = program name
    cmd.executeCLI(args[1..$]);
}
