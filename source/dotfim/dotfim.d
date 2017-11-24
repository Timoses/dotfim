module dotfim.dotfim;


import std.stdio;

import dotfim.git;
import dotfim.gitdot;

class DotfileManager
{
    import std.path;

    enum dotfimGitBranch = "dotfim";

    struct Settings
    {
        private bool _bInitialized;
        @property bool isInitialized() { return this._bInitialized; }

        string settingsFile;

        struct Internal
        {
            // The path where the dotfiles should be synchronized to
            string dotPath;

            // The path from where dotfiles are synchronized from
            // (must be a path to a git repository)
            string gitPath;

            // The remote git Repository URI
            string gitRepo;
        }
        Internal internal;

        @property string dotPath() { return this.internal.dotPath; }
        @property string gitPath() { return this.internal.gitPath; }
        @property string gitRepo() { return this.internal.gitRepo; }
        @property void dotPath(string newEntry) {
            this.internal.dotPath = newEntry; }
        @property void gitPath(string newEntry) {
            this.internal.gitPath = newEntry; }
        @property void gitRepo(string newEntry) {
            this.internal.gitRepo = newEntry; }

        this(this)
        {
            assert(
                    this.internal.dotPath != "" &&
                    this.internal.gitPath != "" &&
                    this.internal.gitRepo != ""
                  );
            this._bInitialized = true;
        }

        this(string settingsFile)
        {
            import std.file : readText, exists;
            import std.exception : enforce;

            enforce(exists(settingsFile), "No settings seem to be stored. Please run dotfim sync");

            import std.json;
            auto json = parseJSON(readText(settingsFile));

            // The settings json must contain our entries
            enforce("dotPath" in json && "gitRepo" in json
                    && "gitPath" in json,
                    "Please run dotfim sync");

            this.dotPath = json["dotPath"].str;
            this.gitPath = json["gitPath"].str;
            this.gitRepo = json["gitRepo"].str;

            this._bInitialized = true;
        }

        void save()
        {
            assert(this.settingsFile != "");

            import std.file : remove, exists;
            if (exists(settingsFile)) remove(settingsFile);

            import std.stdio : File;
            File json = File(settingsFile, "w");

            import vibe.data.json : serializeToJsonString;
            string toFile = this.internal.serializeToJsonString();

            assert(toFile != ""); // prevents writing empty string on crash

            json.write(toFile);
            json.close();
        }
    }
    Settings settings;

    Git git;

    // Contains GitDots of actively managed dotfiles
    GitDot[] gitdots;

    static string[] excludedDotFiles = [".git", ".gitignore"];

    this(string settingsFile)
    {
        this.settings = Settings(settingsFile);
        this();
    }

    this(ref in Settings settings)
    {
        this.settings = settings;
        // save the settings to disk
        this.settings.save();
        this();
    }

    this()
    {
        assert(this.settings.isInitialized);

        // Prepare git path
        this.git = new Git(this.settings.gitPath);
        this.git.saveBranch();
        this.git.setBranch(dotfimGitBranch);

        string gitHash = this.git.hash;

        import std.file;
        // Create a GitDot for every dotfile in gitPath
        foreach (string name; dirEntries(this.settings.gitPath, ".*", SpanMode.shallow))
        {
            import std.algorithm : canFind;
            if (this.excludedDotFiles.canFind(baseName(name)))
                continue;

            try {
                import std.path : buildPath;
                this.gitdots ~= new GitDot(
                        name,
                        buildPath(this.settings.dotPath, name.baseName));
            }
            catch (Exception e) {
                stderr.writeln(name.baseName, " - Error: ", e.message);
            }
        }
    }

    void update()
    {
        string curGitHash = this.git.hash;

        GitDot[] dfUpdatees;
        GitDot[] gfUpdatees;

        // 1: Update Gitfiles
        foreach (gitdot; this.gitdots)
        {
            if (!gitdot.dotfile.managed)
            {
                import std.algorithm : uniq;
                import std.array;
                dfUpdatees = uniq(dfUpdatees ~ gitdot).array;
            }
            else
            {
                string dotGitHash = gitdot.dotfile.gitHash;
                assert(dotGitHash != "", "dotfile's Git Section commit hash can not be empty");
                if (dotGitHash != curGitHash)
                {
                    // dotfile will require rewrite
                    dfUpdatees ~= gitdot;

                    // get content of old git file
                    import std.path : asRelativePath;
                    import std.conv : to;
                    string relGitPath = asRelativePath(
                            gitdot.gitfile.file,
                            this.settings.gitPath).to!string;
                    import std.string : splitLines;
                    import std.range : drop;
                    string[] oldGitLines =
                        this.git.execute("show",
                            dotGitHash ~ ":" ~ relGitPath).output
                            .splitLines()
                            .drop(1); // drop header line

                    // and check for custom updates
                    if (oldGitLines != gitdot.dotfile.gitLines)
                    {
                        // TODO: Merging is currently not allowed
                        // (e.g. git merge-file)
                        throw new Exception("Can not update/merge changes from dotfile with old git commit hash!");
                    }
                }
                else // same git hash
                {
                    // updates/changes in dotfile?
                    if (gitdot.dotfile.gitLines != gitdot.gitfile.gitLines)
                    {
                        import std.algorithm : uniq;
                        import std.array;
                        gfUpdatees = uniq(gfUpdatees ~ gitdot).array;
                    }
                }
            }
        }

        // 2: Commit changes to gitfiles, if any
        if (gfUpdatees.length > 0)
        {
            string changedFiles;
            foreach (gitdot; gfUpdatees)
            {
                gitdot.gitfile.gitLines = gitdot.dotfile.gitLines;
                gitdot.gitfile.write();
                this.git.execute("add", gitdot.gitfile.file);
                import std.conv : to;
                changedFiles ~= asRelativePath(gitdot.gitfile.file,
                                    this.settings.gitPath).to!string
                                ~ "\n";
            }

            import std.string : chomp;
            changedFiles = changedFiles.chomp;

            this.git.execute("commit", "-m",
                    "DotfiM Update: \n\n" ~ changedFiles);
            curGitHash = this.git.hash;

            writeln("Git repo files updated:");
            import std.algorithm : map;
            import std.string : splitLines, join;
            writeln(changedFiles
                    .splitLines
                    .map!((e) => "\t" ~ e)
                    .join("\n"));
        }

        // 3: Update dotfiles
        // if commits done or if oldGitHash found
        if (gfUpdatees.length == 0 && dfUpdatees.length == 0)
        {
            writeln("Everything's already up to date");
        }
        else if (gfUpdatees.length > 0 || dfUpdatees.length > 0)
        {
            writeln("Dotfiles updated:");

            void dfUpdate(GitDot[] dfs)
            {
                // Only git hashs will be updated
                if (dfUpdatees.length == 0)
                    writeln("\tNone");

                foreach (gitdot; dfs)
                {
                    gitdot.dotfile.gitLines = gitdot.gitfile.gitLines;
                    gitdot.dotfile.gitHash = curGitHash;
                    gitdot.dotfile.write();

                    import std.algorithm : canFind;
                    import std.conv : to;
                    // tell user if a dotfile's contents actually changed
                    if (dfUpdatees.canFind(gitdot))
                        writeln("\t" ~
                            asRelativePath(gitdot.dotfile.file,
                                this.settings.dotPath).to!string);
                }
            }

            // new git hash -> update all dotfiles in order
            // to renew their hashes
            if (gfUpdatees.length > 0)
            {
                dfUpdate(this.gitdots);
            }
            else
                dfUpdate(dfUpdatees);
        }
    }

    // Adds dotfiles to git repo and starts managing these files
    // The gitfile should not exist
    // If the dotfile does not exist create it
    void add(string[] dotfiles)
    {
        // update now since after add() new gitHash is commited eventually
        update();

        GitDot[] createdGitDots;

        foreach (file; dotfiles)
        {
            import std.path, std.range;
            import std.algorithm : canFind;
            string absFile = asAbsolutePath(file).array;
            if (!absFile.canFind(this.settings.dotPath))
            {
                stderr.writeln("File ", file, " does not reside within the dotfile path (", this.settings.dotPath, ")!");
                continue;
            }

            if (findGitDot(absFile))
            {
                stderr.writeln("File ", file, " is already managed by DotfiM");
                continue;
            }

            write("Please specify the comment indicator for file ",
                    asRelativePath(file, this.settings.dotPath),
                    ": ");
            import std.string : chomp;
            string commentIndicator = readln().chomp();

            try
            {
                createdGitDots ~= GitDot.create(file.baseName,
                                              commentIndicator,
                                              this.settings.gitPath,
                                              this.settings.dotPath);
            }
            catch (Exception e)
            {
                stderr.writeln(file.baseName, " - Error while creating: ", e.msg);
            }
        }

        if (createdGitDots.length > 0)
        {
            string addedFiles;

            foreach (gitdot; createdGitDots)
            {
                this.git.execute("add", gitdot.gitfile.file);
                addedFiles ~= gitdot.gitfile.file.baseName ~ "\n";
            }

            import std.algorithm : uniq;
            import std.range : array;
            this.gitdots = uniq!((e1,e2) => e1.dotfile.file == e2.dotfile.file)(createdGitDots ~ this.gitdots).array;

            this.git.execute("commit", "-m",
                    "DotfiM Add: \n\n" ~ addedFiles);

            // Update dotfiles with new gitHash version
            // and add new dotfiles
            update();
        }
    }

    // Remove gitFile if existing and write only custom content
    // to dotfile (if none leave it empty)
    void remove(string[] files)
    {
        update();

        string removedFiles;

        foreach (file; files)
        {
            GitDot found = findGitDot(file);
            if (!found)
            {
                stderr.writeln("File ", file, " could not be removed as it is not managed by DotfiM.");
                continue;
            }

            // remove git
            git.execute("rm", found.gitfile.file);
            removedFiles ~= baseName(found.gitfile.file) ~ "\n";

            with (found.dotfile)
            {
                write(customLines);
            }

            import std.algorithm.mutation : remove;
            this.gitdots = this.gitdots.remove!((a) => a == found);
        }

        if (removedFiles != "")
        {
            this.git.execute("commit", "-m",
                    "DotfiM Remove: \n\n" ~ removedFiles);

            writeln("Removed:");
            import std.string : splitLines, join;
            import std.algorithm : map;
            writeln(removedFiles
                        .splitLines
                        .map!((e) => "\t" ~ e)
                        .join("\n"));

            update();
        }
    }

    static DotfileManager sync(string[] repoURI, string settingsFile)
    {
        import std.exception : enforce;
        enforce(repoURI.length == 1, "Can only sync one git repository");

        string dotPath;
        string gitPath;
        string gitRepo = repoURI[0];

        Settings settings;
        try
        {
            settings = Settings(settingsFile);
            writeln("DotfiM is already set up to sync with the following settings:");
            write("\t");
            writeln(settings.internal);
            write("Syncing will delete old setup. Continue? (y/n): ");

            char answer;
            readf!"%c"(answer);

            if (answer != 'y') return null;
            readln(); // flush the 'ENTER'

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
                std.stdio.write(description, " (default: ",
                        path, "): ");

                import std.string : chomp;
                enteredPath = readln().chomp();

                if (enteredPath == "") enteredPath = path;
            } while (!isValidPath(enteredPath));

            return enteredPath;
        }

        writeln("Confirm defaults with ENTER or type desired option");

        import std.path : mkdir, rmdir;
        import std.file : exists;

        string[] pathsCreated;
        scope(failure)
        {
            foreach (path; pathsCreated)
                rmdir(path);
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
        if (exists(gitPath)) rmdirRecurse(gitPath);

        mkdir(gitPath);
        pathsCreated ~= gitPath;

        auto res = Git.staticExecute!(Git.ErrorMode.Ignore)
            ("", "clone", "--branch", dotfimGitBranch, gitRepo, gitPath);
        enforce(res.status == 0, "Could not clone the repository " ~
                gitRepo ~ "\n Git Error: " ~ res.output);

        settings.dotPath = dotPath;
        settings.gitPath = gitPath;
        settings.gitRepo = repoURI[0];
        settings.settingsFile = settingsFile;

        return new DotfileManager(settings);
    }

    GitDot findGitDot(string file)
    {
        import std.path : asAbsolutePath;
        import std.range : array;

        file = asNormalizedPath(asAbsolutePath(file).array).array;

        import std.algorithm : canFind;
        foreach (ref gitdot; this.gitdots)
        {
            if (gitdot.dotfile.file == file)
                return gitdot;
        }

        return null;
    }
}
