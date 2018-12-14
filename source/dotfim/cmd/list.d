module dotfim.cmd.list;

import std.path : asRelativePath;
import std.range : array;
import std.stdio : writeln;

import dotfim.dotfim;

struct List
{
    DotfileManager dfm;

    this(lazy DotfileManager dfm)
    {
        this.dfm = dfm;

        exec();
    }

    private void exec()
    {
        writeln("Managed files:");
        foreach(gitdot; this.dfm.gitdots)
        {
            writeln("\t" ~ asRelativePath(gitdot.gitfile.file,
                        this.dfm.settings.gitdir).array);
        }
    }
}
