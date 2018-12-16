module dotfim.dotfim;

import std.exception : enforce;
import std.path : asRelativePath, asNormalizedPath, dirName;
import std.stdio;

import dotfim.git;
import dotfim.gitdot;
import dotfim.util;

version(unittest)
    shared static this()
    {
        import vibe.core.log;
        setLogLevel(LogLevel.trace);
    }

//.. todo:
//    * dfm passes ALL gitfiles to GitDot, which itself keeps track of if it is managed or not
//    * dfm keeps track of the git hash!! : It describes the state of dfm. After a Sync.updateGit -> it can track whether files have been removed or added, and then remove/add these GitDots and also trigger a reloading of the current GitDots!

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

    // paths or files relative to gitdir that should be excluded
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

        this.git = new Git(this.settings.gitdir);
        this.git.setBranch(dotfimGitBranch);

        load();
    }

    // Loads managed GitDot pairs by scanning files in gitdir for the
    // managed header line
    void load()
    {
        // TODO: reimplement this?
        // If synced first time ask if unmanaged files should be
        // turned to managed files
        //bool bManageAllGitFiles;
        //string[] filesToManage;


        // TODO: when loaded and gitdots is not empty, use git knowledge
        //  -> e.g. if hash changed(dfm has to store state as git hash)
        //                        : check what files were changed
        //    -> decide which files require reloading
        //    -> or add/remove

        this.gitdots.length = 0;

        import std.algorithm : filter, any, startsWith, map;
        import std.exception : ifThrown;
        import std.file;
        import std.path : buildPath;
        import std.range : array;
        this.gitdots = this.settings.gitdir.dirEntries(SpanMode.breadth)
                        .filter!(file =>
                            !excludedDots
                                .any!(ex => file.asRelativePath(this.settings.gitdir)
                                                .startsWith(ex)))
                        .map!((gitfile) {
                            string dotfile =
                                    buildPath(this.settings.dotdir,
                                        gitfile.asRelativePath(this.settings.gitdir)
                                               .to!string);
                            return new GitDot(gitfile, dotfile).ifThrown(null);
                        }).filter!(e => e !is null).array;
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
            writeln("... Pushing to git repository ...");
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

    // Finds GitDot based on either a relative file path to git/dot dir or an
    // absolute file path
    GitDot findGitDot(string file)
    {
        import std.algorithm : any, startsWith;
        import std.conv : to;
        import std.path : asAbsolutePath, isAbsolute, buildPath, asNormalizedPath;

        string finddot;
        string findgit;

        file = file.asNormalizedPath.to!string;
        if (file.isAbsolute && ![this.settings.dotdir, this.settings.gitdir]
                .any!((dir) => file.startsWith(dir)))
            return null;
        else
        {
            finddot = buildPath(this.settings.dotdir, file);
            findgit = buildPath(this.settings.gitdir, file);
        }

        foreach (ref gitdot; this.gitdots)
        {
            if (finddot.length > 0 && gitdot.dot.file == finddot)
                return gitdot;
            else if (findgit.length > 0 && gitdot.git.file == findgit)
                return gitdot;
            else if (gitdot.dot.file == file || gitdot.git.file == file)
                return gitdot;
        }

        return null;
    }
}

mixin template OptionsTemplate()
{
    struct Options
    {
        bool bNoRemote;

        import std.getopt;
        GetoptResult result;
        alias result this;
        this(ref string[] args)
        {
            this.result = std.getopt.getopt(args,
                std.getopt.config.stopOnFirstNonOption,
                "no-remote", "Prevents any interaction with the remote repository (no push/pull)", &bNoRemote
                );

            if (this.helpWanted)
                printHelp();
        }

        void printHelp()
        {
            defaultGetoptPrinter("Usage: dotfim <Option> <Command> <Command Options>" ~ "\n"
                    , result.options);

            import dotfim.cmd;
            writeln(CmdHandler.help);

        }
    }
}

mixin template SettingsTemplate()
{
    struct Settings
    {
        import std.path : isAbsolute, isValidPath, buildPath;

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

        @property string gitdir() {
            import std.path : dirName;
            return this.settingsFile.dirName;
        }

        struct Internal
        {
            // The path where the dotfiles should be synchronized to
            string dotdir;
        }
        Internal internal;

        @property string dotdir() { return this.internal.dotdir; }
        @property void dotdir(string newEntry) {
            this.internal.dotdir = newEntry; }

        this(this)
        {
            assert(
                    this.internal.dotdir != ""
                  );
            this._bInitialized = true;
        }

        static isValid(in string settingsFileOrDir)
        {
            try { Settings(settingsFileOrDir); }
            catch(Exception e) { return false; }
            return true;
        }

        this(in string settingsFileOrDir)
        {
            import std.file : readText, exists;

            this.settingsFile = settingsFileOrDir;

            enforce(exists(this.settingsFile),
                "No configuration found. Run dotfim in an initialized directory or run `dotfim init` to initialize.");

            import std.json;
            auto json = parseJSON(readText(this.settingsFile));

            // The settings json must contain our entries
            enforce("dotdir" in json,
                    "Please run dotfim init");

            this.dotdir = json["dotdir"].str;

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

