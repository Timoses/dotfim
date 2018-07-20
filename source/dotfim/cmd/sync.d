module dotfim.cmd.sync;

import std.algorithm : canFind;
import std.exception : enforce;
import std.path : buildPath, dirName, isValidPath;
import std.stdio : writeln, readln, write;

import dotfim.dotfim;
import dotfim.util.ui;

struct Sync
{
    string settingsFile;
    string gitRepo;

    this(string settingsFile, string[] args = null)
    {
        import std.exception : enforce;
        enforce(args, "Usage: dotfim sync <repoURL>");

        this.settingsFile = settingsFile;
        // TODO: validate git repo uri?
        this.gitRepo = args[0];

        import dotfim.cmd.update;
        Update(exec());
    }

    private DotfileManager exec()
    {
        DotfileManager.Settings settings = interrogateUser();
        return setup(settings);
    }

    // Use settings to create folders and clone repository (gitRepo)
    // into git folder
    DotfileManager setup(DotfileManager.Settings settings)
    {
        import std.file : exists, mkdir, rmdir;
        import std.file : rmdirRecurse;

        string[] pathsCreated;
        scope(failure)
        {
            import std.file : rmdirRecurse;
            foreach (path; pathsCreated)
            {
                if (exists(path))
                {
            //        rmdirRecurse(path);
                }
            }
        }
        with(settings)
        {
            if (!exists(dotPath))
            {
                mkdir(dotPath);
                pathsCreated ~= dotPath;
            }

            mkdir(gitPath);
            pathsCreated ~= gitPath;

            import dotfim.git;
            immutable string dfbranch = DotfileManager.dotfimGitBranch;
            // first check if remote has
            auto res = Git.staticExecute!(Git.ErrorMode.Ignore)
                ("", "ls-remote", "--heads", this.gitRepo);
            // dotfim branch exists!
            if (res.output.canFind("refs/heads/" ~ dfbranch))
            {
                res = Git.staticExecute!(Git.ErrorMode.Ignore)
                    ("", "clone", "--single-branch", "-b",
                     dfbranch, this.gitRepo, gitPath);
            }
            else
            {
                res = Git.staticExecute!(Git.ErrorMode.Ignore)
                    ("", "clone", this.gitRepo, gitPath);
                Git.staticExecute(gitPath, "checkout", "-b", dfbranch);

            }
            enforce(res.status == 0, "Could not clone the repository " ~
                    this.gitRepo ~ "\n Git Error: " ~ res.output);


            // Create an initial commit if repository is empty
            res = Git.staticExecute!(Git.ErrorMode.Ignore)
                (gitPath, "rev-parse", "--abbrev-ref", "HEAD");
            if (res.status != 0)
            {
                Git.staticExecute(gitPath, "commit", "--allow-empty",
                        "-m", "Initial commit");
                Git.staticExecute(gitPath, "push", "origin", dfbranch);
            }


            // save the settings to disk
            save();
        }

        return new DotfileManager(settings);
    }

    DotfileManager.Settings interrogateUser()
    {
        string dotPath;
        string gitPath;

        with (DotfileManager)
        {
            Settings settings;
            try
            {
                settings = Settings(settingsFile);

                import std.conv : to;
                string question =
                    "DotfiM is already set up to sync with the following settings:\n"
                    ~ "\t" ~ settings.internal.to!string ~ "\n"
                    ~ "Syncing will delete old setup. Continue? (y/n): ";

                import std.exception : enforce;
                enforce(askContinue(question, "y"), "Aborted by user");

                // keep current path setup
                dotPath = settings.dotPath;
                gitPath = settings.gitPath;
            }
            catch (Exception e)
            {
                // settingsFile seems corrupt
                writeln("... No settings file found, will create new one");

                // Generate default locations
                import std.process : environment;
                dotPath = environment.get("HOME");

                import std.file;
                gitPath = buildPath(thisExePath().dirName, "dotfimRepo");
            }

            writeln("Confirm defaults with ENTER or type desired option");

            // Ask user for desired locations
            dotPath = askPath("Your home path", dotPath);
            gitPath = askPath("DotfiM Git Repository Path", gitPath);

            import std.file : exists;
            // ask if an existing gitPath should be deleted
            if (exists(gitPath))
            {
                import std.exception : enforce;
                enforce(askContinue("The given git repository path already exists!\n\t!!! Continuing will delete the git repository folder !!!"
                            ~ "\nContinue? (y/n): ", "y"),
                        "Aborted by User.");

                import std.file : rmdirRecurse;
                rmdirRecurse(gitPath);
            }


            settings.bFirstSync = true;

            settings.dotPath = dotPath;
            settings.gitPath = gitPath;
            settings.gitRepo = this.gitRepo;

            settings.settingsFile = settingsFile;

            return settings;
        }
    }
}
