module dotfim.updater;


import std.stdio;

import dotfim.git;

class DotfileUpdater
{
    import std.path;
    import dotfim.dotfile;

    enum dotfimGitBranch = "dotfim";

    string homePath;
    string dotFilesPath;

    Git git;

    Dotfile[] dotfiles;

    static string[] excludeDotFiles = [".git", ".gitignore"];

    this()
    {
        import std.process : environment;
        homePath = environment.get("HOME");
        dotFilesPath = homePath ~ "/dotfiles";

        this.git = new Git(dotFilesPath);
        this.git.saveBranch();
        this.git.setBranch(dotfimGitBranch);

        import std.file;
        foreach (string name; dirEntries(dotFilesPath, ".*", SpanMode.shallow))
        {
            import std.algorithm;
            if (this.excludeDotFiles.canFind(baseName(name)))
                continue;

            try {
                dotfiles ~= new Dotfile(name, homePath);
            } catch (Exception e) {
                stderr.writeln(name, " - Error: ", e.message);
            }

            dotfiles[$-1].setHash(this.git.hash);
        }
    }

    void update()
    {
        foreach (dotfile; this.dotfiles)
        {
            //if (dotfile.update())
            {
                // commit changes or git add ...
            }
        }
    }

    void destroy()
    {
        foreach (dotfile; this.dotfiles)
            dotfile.destroy();
        this.git.resetBranch();
    }
}
