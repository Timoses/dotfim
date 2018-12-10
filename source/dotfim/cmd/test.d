module dotfim.cmd.test;

        import std.stdio;

import std.array : array;
import std.conv : to;
import std.exception : enforce;
import std.path : asAbsolutePath, asNormalizedPath, buildPath;

import dotfim.dotfim;


struct Test
{
    // Directory where test environment should be set up
    immutable string dir;
    immutable string gitdir;
    immutable string dotdir;
    immutable string repodir;


    this(const string[] args)
    {
        enforce(args.length == 1, "Usage: dotfim test <directory>");

        this.dir = args[0].asAbsolutePath.asNormalizedPath.array.to!string;
        this.gitdir = buildPath(this.dir, "git");
        this.dotdir = buildPath(this.dir, "dot");
        this.repodir = buildPath(this.dir, "repo.git");

        exec();

        writeln("Start with 'cd " ~ this.dir ~ " && dotfim init repo/'");
    }

    private void exec()
    {
        import std.file : exists, dirEntries, mkdirRecurse, rmdirRecurse, SpanMode;
        enforce(!dir.exists
            || dir.dirEntries(SpanMode.shallow).empty,
            "Directory \"" ~ dir ~ "\" is not empty!");

        if (!dir.exists)
            mkdirRecurse(dir);

        createTestDirectory();
        createTestFiles();

        DotfileManager.Settings settings;
        settings.dotPath = this.dotdir;
        settings.gitPath = this.gitdir;
        settings.gitRepo = this.repodir;

        settings.settingsFile = buildPath(this.dir, "dotfim.json");

        rmdirRecurse(this.gitdir);
    }

    private void createTestDirectory()
    {
        import std.file : mkdir;
        import std.process : execute;

        mkdir(repodir);
        execute(["git", "init", "--bare", repodir]);
        mkdir(gitdir);
        execute(["git", "clone", repodir, gitdir]);
        mkdir(dotdir);

    }

    private void createTestFiles()
    {
        import std.algorithm : each;
        import std.file : write;
        import std.format : format;

        import dotfim.git;
        import dotfim.gitdot;

        enum commentIndicator = "#";

        Git git = new Git(this.gitdir);

        // Gitfiles
        ["1", "2"].each!(n => write(buildPath(this.gitdir, ".file"~n),
                   commentIndicator ~ " " ~ GitDot.fileHeader
                   ~ format(q"EOF

git%s line 1
git%s line 2
EOF"
                , n, n)));
        git.setBranch(DotfileManager.dotfimGitBranch);
        git.execute("add", "-A");
        git.execute("commit", "-m", "\"First test commit\"");
        git.push(DotfileManager.dotfimGitBranch);

        // Dotfile
        ["1"].each!(n => write(buildPath(this.dotdir, ".file"~n),
                   format(q"EOF
dot%s line 1
dot%s line 2
EOF"
                , n, n)));
    }
}
