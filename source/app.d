
import dotfim.updater;
import dotfim.cmd;

void main(string[] args)
{
	auto upd = new DotfileUpdater();
    auto cmd = new CmdHandler(upd);

    cmd.executeCLI(args);
    upd.update();
    upd.destroy();
}
