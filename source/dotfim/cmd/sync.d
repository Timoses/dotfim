module dotfim.cmd.sync;

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

                if (!askContinue(question, "y"))
                    return null;

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

            string askPath(string description, string path)
            {
                string enteredPath;

                do
                {
                    write(description, " (default: ",
                            path, "): ");

                    import std.string : chomp;
                    enteredPath = readln().chomp();

                    if (enteredPath == "") enteredPath = path;
                } while (!isValidPath(enteredPath));

                return enteredPath;
            }

            writeln("Confirm defaults with ENTER or type desired option");

            import std.file : exists, mkdir, rmdir;

            string[] pathsCreated;
            scope(failure)
            {
                import std.file : rmdirRecurse;
                foreach (path; pathsCreated)
                {
                    if (exists(path))
                    {
                        rmdirRecurse(path);
                    }
                }
            }
            // Ask user for desired locations
            dotPath = askPath("Your home path", dotPath);
            if (!exists(dotPath))
            {
                mkdir(dotPath);
                pathsCreated ~= dotPath;
            }

            gitPath = askPath("DotfiM Git Repository Path", gitPath);

            import std.file : rmdirRecurse;
            // ask if an existing gitPath should be deleted
            if (exists(gitPath))
            {
                if (!askContinue("The given git repository path already exists!\n\t!!! Continuing will delete the git repository folder !!!"
                            ~ "\nContinue? (y/n): ", "y"))
                        return null;

                rmdirRecurse(gitPath);
            }

            mkdir(gitPath);
            pathsCreated ~= gitPath;

            import dotfim.git;
            auto res = Git.staticExecute!(Git.ErrorMode.Ignore)
                ("", "clone", "--single-branch", "-b", "dotfim", this.gitRepo, gitPath);
            enforce(res.status == 0, "Could not clone the repository " ~
                    this.gitRepo ~ "\n Git Error: " ~ res.output);

            settings.bFirstSync = true;

            settings.dotPath = dotPath;
            settings.gitPath = gitPath;
            settings.gitRepo = this.gitRepo;

            settings.settingsFile = settingsFile;

            return new DotfileManager(settings);
        }
    }
}
