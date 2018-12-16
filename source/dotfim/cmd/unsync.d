module dotfim.cmd.unsync;

import std.stdio : writeln, write;

import dotfim.dotfim;

struct Unsync
{
    DotfileManager dfm;

    this(lazy DotfileManager dfm)
    {
        this.dfm = dfm;

        exec();
    }

    private void exec()
    {
        import dotfim.util : askContinue;
        if (!askContinue("Unsync will unmanage all dotfiles managed by DotfiM\n"
                      ~ "Additionally, your current setup will be removed\n"
                      ~ "Are you sure to continue? (y/n)", "y"))
            return;

        with (this.dfm)
        {
            string[] files;
            foreach(gitdot; dfm.gitdots)
            {
                import std.range : array;
                files ~= gitdot.git.file;
            }

            // unmanage all files
            {
                scope(failure)
                    writeln("Error while unmanaging files... Aborting unsync!");
                import dotfim.cmd.remove;
                Remove(this.dfm, files);
            }
            writeln("All files successfully unmanaged.");

            // remove dotfim repo
            import std.file : rmdirRecurse, exists;
            if (exists(settings.gitdir))
                rmdirRecurse(settings.gitdir);

            // remove
            write("Removing settings ...");
            settings.remove();
            writeln("Removed!");
        }
    }
}
