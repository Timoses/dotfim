module dotfim.dotfim;


import std.stdio;

import dotfim.git;
import dotfim.gitdot;

class DotfileManager
{
    import std.path;

    enum dotfimGitBranch = "dotfim";

    mixin OptionsTemplate;
    Options options;

    mixin SettingsTemplate;
    Settings settings;

    Git git;

    // Contains GitDots of actively managed dotfiles
    GitDot[] gitdots;

    // paths or files relative to gitPath that should be excluded
    static string[] excludedDots = [".git", ".gitignore", "cheatSheets"];

    this(string settingsFile, Options options)
    {
        this.settings = Settings(settingsFile);
        this.options = options;
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

        this.git = new Git(this.settings.gitPath);
        prepareGitBranch();

        string gitHash = this.git.hash;

        // If synced first time ask if unmanaged files should be
        // turned to managed files
        bool bManageAllGitFiles;
        string[] filesToManage;

        void processDirectory(string dir, int depth = 0)
        {
            import std.file;


            foreach (string gitFileName; dirEntries(dir, SpanMode.shallow))
            {
                import std.algorithm : canFind;
                import std.range : array;

                string relFilePath = gitFileName.asRelativePath(this.settings.gitPath).array;
                // ignore excluded files or folders
                if (this.excludedDots.canFind(relFilePath))
                    continue;

                if (gitFileName.isDir)
                    processDirectory(gitFileName);
                else
                {
                    try {
                        import std.path : buildPath;

                        string dotFileName = buildPath(this.settings.dotPath, relFilePath);

                        // create dotfile's path if it doesn't exist yet
                        if (!dotFileName.dirName.exists)
                            mkdirRecurse(dotFileName.dirName);

                        this.gitdots ~= new GitDot(gitFileName, dotFileName);
                    }
                    catch (NotManagedException e)
                    {
                        if (bManageAllGitFiles)
                        {
                            filesToManage ~= gitFileName;
                        }
                        else if (this.settings.isFirstSync
                                 && askContinue(
                                "DotfiM can start managing all existing files in your git repository now.\n You may as well add them individually later using the \"add\" command.\nManage all files now? (y/n): ", "y"))
                        {
                            filesToManage ~= gitFileName;
                            bManageAllGitFiles = true;
                        }
                        else // stop asking ...
                            this.settings.bFirstSync = false;
                    }
                    catch (Exception e) {
                        stderr.writeln(relFilePath, " - Error: ", e.msg);
                    }
                }
            }
        }

        // load all GitDots from gitFiles
        processDirectory(this.settings.gitPath);

        if (bManageAllGitFiles && filesToManage.length > 0)
            this.add(filesToManage);
    }

    void prepareGitBranch()
    {
        this.git.saveBranch();
        this.git.setBranch(dotfimGitBranch);

        if (!this.options.bNoRemote)
        {
            writeln("... Fetching remote repository ...");
            this.git.execute("fetch");
        }

        string local = this.git.hash;
        string remote = this.git.remoteHash;

        if (local != remote)
        {
            import std.algorithm : canFind;
            // remote branch is ahead -> checkout remote
            if (this.git.execute("branch", "-a", "--contains", this.dotfimGitBranch).output.canFind("origin/" ~ this.dotfimGitBranch))
            {
                writeln("... Checking out remote repository ...");
                this.git.execute("checkout", "-B", this.dotfimGitBranch,
                        "origin/" ~ this.dotfimGitBranch);
                writeln("Checked out remote branch: ", remote[0..6]);
            }

            // remote and local branches diverged -> block!
            import std.string : chomp;
            string mergeBase = this.git.execute("merge-base",
                    this.dotfimGitBranch,
                    "origin/" ~ this.dotfimGitBranch).output.chomp;
            import std.exception : enforce;
            enforce(mergeBase != ""
                    && (mergeBase == local || mergeBase == remote),
                    "Remote and local branches diverged! Please fix manually.");

            // else: local is ahead of remote?
            if (!this.options.bNoRemote
                    && this.git.execute("branch", "--contains",
                        "origin/" ~ this.dotfimGitBranch).output
                    .canFind("* dotfim"))
            {
                writeln("... Pushing to remote repository ...");
                this.git.push(this.dotfimGitBranch);
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
                        throw new Exception(
                                gitdot.dotfile.file ~
                                " - Can not update/merge changes from dotfile with old git commit hash!");
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

            this.commitAndPush("DotfiM Update: \n\n" ~ changedFiles);
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

        import std.algorithm : map;
        import std.path : asNormalizedPath, asAbsolutePath;
        import std.range : array;
        import std.conv : to;

        // sanitize paths
        dotfiles = dotfiles.map!((dotfile) =>
                asNormalizedPath(asAbsolutePath(dotfile).array).array
                .to!string).array;

        foreach (file; dotfiles)
        {
            import std.path;
            import std.algorithm : canFind;

            bool bIsGitFile =
                file.canFind(this.settings.gitPath);
            bool bIsDotFile = bIsGitFile ? false
                : file.canFind(this.settings.dotPath);

            if (!(bIsGitFile || bIsDotFile))
            {
                stderr.writeln("File ", file, " does neither reside within the dotfile path (", this.settings.dotPath, ") nor git path (", this.settings.gitPath, ")!\n\tSkipping");
                continue;
            }

            if (findGitDot(file))
            {
                stderr.writeln("File ", file, " is already managed by DotfiM");
                continue;
            }

            string relFile = asRelativePath(file,
                    bIsGitFile ? this.settings.gitPath :
                    bIsDotFile ? this.settings.dotPath : "").array;

            assert(relFile != "");

            write("Please specify the comment indicator for file ",
                    relFile,
                    ": ");
            import std.string : chomp;
            string commentIndicator = readln().chomp();

            try
            {
                createdGitDots ~= GitDot.create(
                                          relFile,
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
                addedFiles ~= asRelativePath(gitdot.gitfile.file,
                        this.settings.gitPath).array ~ "\n";
            }

            import std.algorithm : uniq;
            import std.range : array;
            this.gitdots = uniq!((e1,e2) => e1.dotfile.file == e2.dotfile.file)(createdGitDots ~ this.gitdots).array;

            this.commitAndPush("DotfiM Add: \n\n" ~ addedFiles);

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

        writeln("------------------------");

        string unmanagedFiles;

        foreach (file; files)
        {
            GitDot found = findGitDot(file);

            if (!found)
            {
                stderr.writeln("File ", file, " could not be removed as it is not managed by DotfiM.");
                continue;
            }

            // remove header from gitFile
            found.gitfile.write(true);

            git.execute("add", found.gitfile.file);

            import std.range : array;
            unmanagedFiles ~= asRelativePath(found.gitfile.file,
                        this.settings.gitPath).array ~ "\n";

            // write only local section to dotfile
            with (found.dotfile)
            {
                write(localLines);
            }

            import std.algorithm.mutation : remove;
            this.gitdots = this.gitdots.remove!((a) => a == found);
        }

        if (unmanagedFiles != "")
        {
            this.commitAndPush("DotfiM Unmanage: \n\n" ~ unmanagedFiles);

            writeln("Unmanaged:");
            import std.string : splitLines, join;
            import std.algorithm : map;
            writeln(unmanagedFiles
                        .splitLines
                        .map!((e) => "\t" ~ e)
                        .join("\n"));

            writeln("------------------------");

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
            import std.file : rmdirRecurse;
            foreach (path; pathsCreated)
                rmdirRecurse(path);
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

        auto res = Git.staticExecute!(Git.ErrorMode.Ignore)
            ("", "clone", "--branch", dotfimGitBranch, gitRepo, gitPath);
        enforce(res.status == 0, "Could not clone the repository " ~
                gitRepo ~ "\n Git Error: " ~ res.output);

        settings.bFirstSync = true;

        settings.dotPath = dotPath;
        settings.gitPath = gitPath;
        settings.gitRepo = repoURI[0];

        settings.settingsFile = settingsFile;

        return new DotfileManager(settings);
    }

    void list()
    {
        writeln("Managed files:");
        foreach(gitdot; this.gitdots)
        {
            import std.range : array;
            writeln("\t" ~ asRelativePath(gitdot.gitfile.file, this.settings.gitPath).array);
        }
    }

    void commitAndPush(string commitMsg)
    {
        this.git.commit(commitMsg);

        if (!this.options.bNoRemote)
        {
            writeln("... Reaching out to git repository ...");
            try
            {
                this.git.push(dotfimGitBranch);
            }
            catch (Exception e)
            {
                writeln("... Error while pushing to remote repository:\n\t", e.msg);
            }
        }
    }

    GitDot findGitDot(string file)
    {
        import std.path : asAbsolutePath;
        import std.range : array;

        file = asNormalizedPath(asAbsolutePath(file).array).array;

        import std.algorithm : canFind;
        foreach (ref gitdot; this.gitdots)
        {
            if (gitdot.dotfile.file == file
                || gitdot.gitfile.file == file)
                return gitdot;
        }

        return null;
    }

    static bool askContinue(string question, string yes)
    {
            write(question);

            string answer;
            import std.string : chomp;
            answer = readln().chomp();

            return answer != yes ? false : true;
    }
}

mixin template OptionsTemplate()
{
    struct Options
    {
        bool bNeededHelp;
        bool bNoRemote;

        static Options process(ref string[] inOptions)
        {
            Options options;
            import std.getopt;

            with(options)
            {
                auto rslt = getopt(inOptions,
                        "no-remote", "Prevents any interaction with the remote repository (no push/pull)", &bNoRemote);

                if (rslt.helpWanted)
                {
                    options.bNeededHelp = true;
                    defaultGetoptPrinter("DotfiM - the following options are available:", rslt.options);
                }
            }
            return options;
        }
    }
}

mixin template SettingsTemplate()
{
    struct Settings
    {
        // set when this is the first time the git Repo is synced
        private bool _bFirstSync;
        @property bool isFirstSync() { return this._bFirstSync; }
        @property void bFirstSync(bool firstSync) {
            this._bFirstSync = firstSync; }

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
}

