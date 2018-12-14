module dotfim.cmd.init;

import std.algorithm : canFind, map;
import std.exception : enforce;
import std.file : exists, mkdir, rmdir, rmdirRecurse;
import std.path : asAbsolutePath, asNormalizedPath, buildPath, dirName, isValidPath;
import std.stdio : writeln, readln, write;
import std.string : empty;

import dotfim.dotfim;
import dotfim.git;
import dotfim.util.ui;


// Initializes the dotfim git folder, ensures a 'dotfim' branch exists and
// writes the dotfim configuration file into it
// If option '--gitdir' is not passed, uses the git Repo URL basename as the git
// folder in the current working directory
struct Init
{
    enum string Usage = "dotfim init <repoURL> [<directory>]";
    string repodir;

    Options options;
    alias options this ;

    this(string[] args = null)
    {
        this.options = Options(args);
        if (this.options.helpWanted)
            return;

        scope(failure) this.options.printHelp;
        enforce(args.length > 1, "Wrong number of arguments");

        this.repodir = Git.toRepoURL(args[1]);

        if (args.length > 2)
            this.options.gitdir = args[2];

        if (this.options.gitdir.empty)
        {
            import std.path : baseName;
            this.options.gitdir = this.repodir.baseName;
        }

        exec();
    }

    debug {
        import dotfim.cmd.test;
        this(Test testenv)
        {
            this.repodir = testenv.repodir;
            this.dotdir = testenv.dotdir;
            this.gitdir = testenv.gitdir;
        }
    }

    DotfileManager exec()
    {
        Git git;
        immutable string dfbranch = DotfileManager.dotfimGitBranch;

        enforce(!this.gitdir.exists, "Git directory \"" ~ this.gitdir
                ~ "\" already exists");

        { // Clone repository into gitdir
            if (Git.branchExists(this.repodir, dfbranch))
            {
                auto res = Git.staticExecute("", "clone", "--single-branch", "-b",
                     dfbranch, this.repodir, this.gitdir);
            }
            else
            {
                auto res = Git.staticExecute!(Git.ErrorMode.Ignore)
                    ("", "clone", this.repodir, this.gitdir);
                Git.staticExecute(this.gitdir, "checkout", "-b", dfbranch);
            }

            // Create an initial commit if repository is empty
            auto res = Git.staticExecute!(Git.ErrorMode.Ignore)
                (this.gitdir, "rev-parse", "--abbrev-ref", "HEAD");
            if (res.status != 0)
            {
                Git.staticExecute(this.gitdir, "commit", "--allow-empty",
                        "-m", "Initial commit");
                Git.staticExecute(this.gitdir, "push", "origin", dfbranch);
            }
        }

        DotfileManager.Settings settings;
        import std.process : environment;
        settings.settingsFile = this.gitdir;
        settings.dotdir = this.dotdir.empty ?
                             askPath("Your home path", environment.get("HOME"))
                             : this.dotdir;

        settings.save();

        return new DotfileManager(settings);;
    }
}

struct Options
{
    private string _dotdir;
    @property string dotdir() { return this._dotdir; }
    @property void dotdir(string dir) {
        this._dotdir = dir.asAbsolutePath.asNormalizedPath.to!string; }
    private string _gitdir;
    @property string gitdir() { return this._gitdir; }
    @property void gitdir(string dir) {
        this._gitdir = dir.asAbsolutePath.asNormalizedPath.to!string; }

    import std.getopt;
    GetoptResult result;
    alias result this;

    this(ref string[] args)
    {
        string gitdir;
        string dotdir;
        this.result = std.getopt.getopt(args,
            "dotdir", "<dir>: Set path where dotfiles will be synced to", &dotdir,
            "gitdir", "<dir>: Clone repository contents into <dir>", &gitdir,
            );

        this.gitdir = gitdir;
        this.dotdir = dotdir;

        if (this.result.helpWanted)
            printHelp();
    }

    void printHelp()
    {
        defaultGetoptPrinter("Usage: " ~ Init.Usage ~ "\n"
                , result.options);

    }
}
