module dotfim.dotfim;

import std.path : asRelativePath, asNormalizedPath, dirName;
import std.stdio;

import dotfim.git;
import dotfim.gitdot;
import dotfim.util;

class DotfileManager
{

    enum dotfimGitBranch = "dotfim";

    mixin OptionsTemplate;
    Options options;

    mixin SettingsTemplate;
    Settings settings;

    Git git;

    // Contains GitDots of actively managed dotfiles
    GitDot[] gitdots;

    // paths or files relative to gitPath that should be excluded
    static string[] excludedDots = [".git", "cheatSheets"];

    this(string dir, Options options = Options())
    {
        this.settings = Settings(dir);
        this.options = options;
        this();
    }

    this(ref in Settings settings)
    {
        this.settings = settings;
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
        {
            import dotfim.cmd.add;
            Add(this, filesToManage);
        }
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

        // remote branch exists and differs
        if (remote.length > 0 && local != remote)
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

    void commitAndPush(string commitMsg)
    {
        this.git.commit(commitMsg);
        push();
    }

    void push()
    {
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
        enum defaultFileName = "dotfim.json";

        // set when this is the first time the git Repo is synced
        private bool _bFirstSync;
        @property bool isFirstSync() { return this._bFirstSync; }
        @property void bFirstSync(bool firstSync) {
            this._bFirstSync = firstSync; }

        private bool _bInitialized;
        @property bool isInitialized() { return this._bInitialized; }

        private string _settingsFile;
        @property string settingsFile() { return this._settingsFile; }
        @property void settingsFile(string settingsFileOrDir)
        {
            import std.file : isDir, exists;
            import std.path : buildPath, extension;
            if (settingsFileOrDir.extension == ".json")
                this._settingsFile = settingsFileOrDir;
            else if (settingsFileOrDir.exists && settingsFileOrDir.isDir)
                this._settingsFile = buildPath(settingsFileOrDir, defaultFileName);
            else
                enforce(false,
                    "Invalid settings file or folder: \"" ~ settingsFileOrDir ~ "\"");
        }

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

        this(in string settingsFileOrDir)
        {
            import std.file : readText, exists;
            import std.exception : enforce;

            this.settingsFile = settingsFileOrDir;

            enforce(exists(this.settingsFile),
                "\""~this.settingsFile~"\" does not exist. Please run dotfim sync");

            import std.json;
            auto json = parseJSON(readText(this.settingsFile));

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

        void remove()
        in
        {
            assert(this.settingsFile != "");
        }
        body
        {
            import std.file : exists, remove;
            if (exists(this.settingsFile))
                remove(this.settingsFile);

        }
    }
}

