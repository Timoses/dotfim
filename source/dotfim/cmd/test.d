module dotfim.cmd.test;

        import std.stdio;

import std.array : array;
import std.conv : to;
import std.exception : enforce;
import std.file : tempDir;
import std.path : asAbsolutePath, asNormalizedPath, buildPath;

import dotfim.dotfim;


struct Test
{
    // Directory where test environment should be set up
    immutable string dir;
    // Temporary git directory
    immutable string gitdir;

    Options options;

    this(string[] args)
    {
        import dotfim.util.getopt;
        this.options = process!Options(args);
        if (this.options.helpWanted)
            return;

        enforce(args.length >= 2, "Usage: dotfim test <directory>");

        this.dir = args[1].asAbsolutePath.asNormalizedPath.array.to!string;
        this.gitdir = buildPath(tempDir, "dotfim", "gitdir");
        with(this.options)
        {
            import std.string : empty;
            dotdir = dotdir.empty ? buildPath(this.dir, "dot") : dotdir;
            repodir = repodir.empty ? buildPath(this.dir, "repo.git") : repodir;
        }

        exec();

        writeln("Start with 'cd " ~ this.dir ~ " && dotfim init "
                ~ this.options.repodir ~ "'");
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
        settings.dotPath = this.options.dotdir;
        settings.gitPath = this.gitdir;
        settings.gitRepo = this.options.repodir;

        settings.settingsFile = buildPath(this.dir, "dotfim.json");

        rmdirRecurse(this.gitdir);
    }

    private void createTestDirectory()
    {
        import std.file : mkdir;
        import std.process : execute;

        mkdir(options.repodir);
        execute(["git", "init", "--bare", options.repodir]);
        execute(["git", "clone", options.repodir, this.gitdir]);
        mkdir(options.dotdir);

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
        ["1"].each!(n => write(buildPath(this.options.dotdir, ".file"~n),
                   format(q"EOF
dot%s line 1
dot%s line 2
EOF"
                , n, n)));
    }
}

struct Options
{
    string dotdir;
    string repodir;

    import std.getopt;
    GetoptResult result;
    alias result this;

    this(ref string[] args)
    {
        this.result = std.getopt.getopt(args,
            std.getopt.config.stopOnFirstNonOption,
            "dotdir", "<dir>: Create test home directory in <dir>", &dotdir,
            "repodir", "<repo>: Create test remote repository in <repo>", &repodir,
            );
    }
}
