module dotfim.cmd.test;

import std.array : array;
import std.conv : to;
import std.exception : enforce;
import std.file : tempDir;
import std.path : asAbsolutePath, asNormalizedPath, buildPath;
import std.stdio : writeln;

import dotfim.dotfim;


struct Test
{
    enum Usage = "dotfim test <directory>";

    // Directory where test environment should be set up
    immutable string dir;
    // git directory
    immutable string gitdir;

    Options options;
    alias options this;

    this(string[] args)
    {
        this.options = Options(args);
        if (this.options.helpWanted)
            return;

        scope(failure) this.options.printHelp();
        enforce(args.length >= 2, "Wrong number of arguments");

        this.dir = args[1].asAbsolutePath.asNormalizedPath.array.to!string;
        this.gitdir = buildPath(this.dir, "git");
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

    this(string dir)
    {
        this(["test", dir]);
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
        ["1","3"].each!(n => write(buildPath(this.options.dotdir, ".file"~n),
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

        if (this.helpWanted)
            printHelp();
    }

    void printHelp()
    {
        defaultGetoptPrinter("Usage: " ~ Test.Usage ~ "\n"
                , result.options);

    }
}

unittest
{
    import std.file : rmdirRecurse, exists;
    string tmp = buildPath(tempDir(), "dotfim", "unittest-test");
    if (tmp.exists) tmp.rmdirRecurse;
    auto test = Test(["test", tmp]);
    import dotfim.git;
    assert(Git.exists(test.options.repodir));

    rmdirRecurse(tmp);
}
