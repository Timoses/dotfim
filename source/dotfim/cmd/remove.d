module dotfim.cmd.remove;

import std.algorithm : map;
import std.conv : to;
import std.path : asNormalizedPath, asAbsolutePath, asRelativePath;
import std.range : array;
import std.stdio : writeln;

import dotfim.dotfim;

struct Remove
{
    DotfileManager dfm;

    string[] dotfiles;

    this(lazy DotfileManager dfm, string[] args = null)
    {
        import std.exception : enforce;
        enforce(args.length > 1, "Usage: dotfim add <file1> <file2> ... <fileN>");

        // sanitize paths
        this.dotfiles = args[1..$].map!((dotfile) =>
                asNormalizedPath(asAbsolutePath(dotfile).array).array
                .to!string).array;

        this.dfm = dfm;

        exec();
    }

    // Remove gitFile if existing and write only custom content
    // to dotfile (if none leave it empty)
    // Also commits and pushes unmanaged gitfiles
    private void exec()
    {
        import dotfim.cmd.update;
        Update(this.dfm);

        writeln("------------------------");

        string unmanagedFiles;
        string[] filesNotManaged;

        with (this.dfm) foreach (file; this.dotfiles)
        {
            import dotfim.gitdot;
            GitDot found = findGitDot(file);

            if (!found)
            {
                filesNotManaged ~= file;
                continue;
            }

            // remove header from gitFile
            found.gitfile.write(true);

            git.execute("add", found.gitfile.file);

            import std.range : array;
            unmanagedFiles ~= asRelativePath(found.gitfile.file,
                        settings.gitdir).array ~ "\n";

            // write only local section to dotfile
            with (found.dotfile)
                write(localLines);

            import std.algorithm.mutation : remove;
            gitdots = gitdots.remove!((a) => a == found);
        }

        import std.string : splitLines, join;
        import std.algorithm : map;
        with (this.dfm) if (unmanagedFiles != "")
        {
            commitAndPush("DotfiM Unmanage: \n\n" ~ unmanagedFiles);

            writeln("Unmanaged:");
            writeln(unmanagedFiles
                        .splitLines
                        .map!((e) => "\t" ~ e)
                        .join("\n"));

            writeln("------------------------");

            import dotfim.cmd.update;
            Update(this.dfm);
        }

        import std.exception : enforce;
        enforce(filesNotManaged.length == 0, "The following files could "
                ~ "not be removed because they are not managed by DotfiM:\n"
                ~ filesNotManaged.map!((e) => "\t" ~ e).join("\n"));
    }
}
