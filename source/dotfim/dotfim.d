module dotfim.dotfim;


import std.stdio;

import dotfim.git;
import dotfim.gitdot;

class DotfileManager
{
    import std.path;

    enum dotfimGitBranch = "dotfim";

    string homePath;
    string dotFilesPath;

    Git git;

    GitDot[] gitdots;

    static string[] excludedDotFiles = [".git", ".gitignore"];

    this(string dotfilesRepo)
    {
        import std.process : environment;
        homePath = environment.get("HOME");
        dotFilesPath = dotfilesRepo;

        this.git = new Git(dotFilesPath);
        this.git.saveBranch();
        this.git.setBranch(dotfimGitBranch);

        import std.file;
        string gitHash = this.git.hash;
        foreach (string name; dirEntries(dotFilesPath, ".*", SpanMode.shallow))
        {
            import std.algorithm : canFind;
            if (this.excludedDotFiles.canFind(baseName(name)))
                continue;

            try {
                import std.path : buildPath;
                this.gitdots ~= new GitDot(
                        name,
                        buildPath(homePath, name.baseName));
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
                            this.dotFilesPath).to!string;
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
                                    this.dotFilesPath).to!string
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
                                this.dotFilesPath).to!string);
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
}
