module dotfim.dotfim;


import std.stdio;

import dotfim.git;
import dotfim.gitdot;

class DotfileManager
{
    import std.path;

    enum dotfimGitBranch = "dotfim";

    string dotPath;
    string gitPath;

    Git git;

    // Contains GitDots of actively managed dotfiles
    GitDot[] gitdots;

    static string[] excludedDotFiles = [".git", ".gitignore"];

    this(string dotfilesRepo)
    {
        import std.process : environment;
        dotPath = environment.get("HOME");
        gitPath = dotfilesRepo;

        this.git = new Git(gitPath);
        this.git.saveBranch();
        this.git.setBranch(dotfimGitBranch);

        import std.file;
        string gitHash = this.git.hash;
        foreach (string name; dirEntries(gitPath, ".*", SpanMode.shallow))
        {
            import std.algorithm : canFind;
            if (this.excludedDotFiles.canFind(baseName(name)))
                continue;

            try {
                import std.path : buildPath;
                this.gitdots ~= new GitDot(
                        name,
                        buildPath(dotPath, name.baseName));
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
                            this.gitPath).to!string;
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
                                    this.gitPath).to!string
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
                                this.gitPath).to!string);
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
    // prompts for creation of non-existing files
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
            if (!absFile.canFind(this.dotPath))
            {
                stderr.writeln("File ", file, " does not reside within the dotfile path (", this.dotPath, ")!");
                continue;
            }

            import std.algorithm : canFind;
            if (this.gitdots.canFind!((e) { return e.dotfile.file == file;}))
            {
                stderr.writeln("File ", file, " is already managed by DotfiM");
                continue;
            }

            write("Please specify the comment indicator for file ",
                    asRelativePath(file, this.dotPath),
                    ": ");
            import std.string : chomp;
            string commentIndicator = readln().chomp();

            try
            {
                createdGitDots ~= GitDot.create(file.baseName,
                                              commentIndicator,
                                              gitPath,
                                              dotPath);
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
                addedFiles ~= gitdot.gitfile.file.baseName;
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
}
