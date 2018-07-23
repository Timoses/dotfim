module dotfim.git;

import std.stdio;

class Git
{
    enum ErrorMode { Throw, Ignore };

    // operating directory
    string dir;

    // saved branch, can be returned to by calling resetBranch()
    string savedBranch;

    this(string gitDir)
    {
        this.dir = gitDir;
    }

    void saveBranch()
    {
        import std.string : chomp;
        this.savedBranch = chomp(
                execute("rev-parse", "--abbrev-ref", "HEAD").output);
    }

    void resetBranch()
    {
        execute("checkout", this.savedBranch);
    }

    // checks out branchName, creates it if it doesn't exist
    void setBranch(string branchName)
    {
        // if branchName does not exist create it
        if (execute!(ErrorMode.Ignore)("rev-parse", "--verify", branchName)
                .status != 0)
            execute("branch", branchName);

        execute("checkout", branchName);
    }

    void commit(string commitMsg, bool amend = false)
    {
        if (amend)
            this.execute("commit", "--amend", "-m", commitMsg);
        else
            this.execute("commit", "-m", commitMsg);
    }

    void push(string branch)
    {
        this.execute("push", "origin", branch);
    }

    @property string hash()
    {
        import std.string : chomp;
        import std.stdio;
        return execute("rev-parse", "HEAD").output.chomp;
    }

    @property string remoteHash(string branchName = "")
    {
        if (branchName == "")
            branchName = execute("symbolic-ref", "--quiet", "--short", "HEAD").output;
        import std.exception : enforce;
        enforce(branchName != "", "Unable to determine branch for remote hash.");
        import std.string : chomp;
        auto res = execute!(ErrorMode.Ignore)("rev-parse", "origin/dotfim");

        // remote branch origin/dotfim does not exist?
        if (res.status > 0)
            return "";
        else
            return res.output.chomp;
    }

    auto execute(ErrorMode eMode = ErrorMode.Throw, string file = __FILE__, int line = __LINE__)(string[] cmds ...)
    {
        return Git.staticExecute!(eMode, file, line)(this.dir, cmds);
    }

    static auto staticExecute(ErrorMode emode = ErrorMode.Throw, string file = __FILE__, int line = __LINE__)(string location, string[] cmds ...)
    {
       import std.process : execute;
       import std.exception : enforce;
       import std.string : empty;

       auto pre = location.empty ? ["git"] : ["git", "-C", location];
       auto res = execute(pre ~ cmds);

       import std.format : format;
       enforce(emode == ErrorMode.Ignore || res.status == 0, format(
                   "%s (%d): Error while executing git %-(%s %)\n Exited with: %s",
                   file, line,
                   cmds,
                   res.output));

       return res;
    }

    // Merges commits from otherBranch and mergeBranch into mergeBranch
    // returns:
    //  true - if successfully merged into mergeBranch
    //  false - if merging failed
    bool merge(string mergeBranch, string otherBranch)
    {
        this.execute("checkout", mergeBranch);
        string divergedHash = this.hash;

        auto res = this.execute!(this.ErrorMode.Ignore)(["merge", otherBranch]);

        import std.string : splitLines;
        import std.algorithm : map;
        import std.array : join;
        writeln("|-- Git Merge ----");
        writeln(res.output.splitLines().map!((e) => "| " ~ e).join("\n"));
        writeln("|-----------------");

        if (res.status > 0)
        { // git conflict
            writeln("| Git merge seems to have been unsuccessful.");
            writeln("| Attempting git merge tool");
            writeln("|-- Git Merge Tool ----");
            import std.process : spawnProcess, wait;
            auto pid = spawnProcess(["git", "-C", this.dir, "mergetool"]);
            wait(pid);
            writeln("|----------------------");

            // git merge tool successful?
            if (wait(pid) == 0)
            {
                // commit git merge would auto commit,
                // need to commit ourselves after git merge tool
                this.execute(["commit", "-m", "Merge commit"]);
            }
            else
            {
                this.execute("merge", "--abort");
                return false;
            }
        }

        // merging should create a new commit
        string mergedHash = this.hash;
        import std.exception : enforce;
        // could this happen when fast-forwarding?...
        //  however, we should never start merging then in the first place
        enforce(mergedHash != divergedHash, "Apparently the "
                ~ "merge did not create a new commit...");

        return true;

    }

    /++unittest
    {
        enum string testRepo = "testRepo";

        import std.file;
        import std.algorithm;
        import std.path;
        Git mgit = new Git(buildPath(thisExePath().dirName, testRepo));

        void PrepareMergeScenario()
        {
            if (exists(testRepo))
                rmdirRecurse(testRepo);
            mkdir(testRepo);

            mgit.execute("init");

            string[] fileNames = [
                buildPath(testRepo, "file1"),
                buildPath(testRepo, "file2")];
            File[] files;
            foreach (filename; fileNames)
                files ~= File(filename, "w");

            files[0].write(q"EOS
Line 1
Line 2
Line 3
EOS");
            files[1].write(q"EOS
Line 11
Line 22
Line 33

Line 55
EOS");

            files.each!(f=>f.flush());

            mgit.execute(["add", "-A"]);
            mgit.execute(["commit", "-m", "\"1\""]);

            files[0].write("Line 4\n");
            files[1].write("Line 66\n");
            files.each!((f) { f.flush(); f.close(); });
            mgit.execute(["commit", "-am", "\"2\""]);
            mgit.execute(["checkout", "-b", "mergeBranch", "HEAD~1"]);
            files[0].open(fileNames[0], "a+");
            files[0].writeln("Line 4\nLine 5\n");
            files[0].flush();
            files[0].sync();
            files[1].open(fileNames[1], "a+");
            files[1].writeln("oh noes");
            files[1].flush();
            mgit.execute(["commit", "-am", "\"diverged\""]);
        }

        PrepareMergeScenario();

        // create merge commit
        if (mgit.merge("mergeBranch", "master"))
        {
            writeln("MERGE SUCCESSFUL");
            mgit.execute("rebase", "mergeBranch", "master");
            mgit.execute("branch", "-d", "mergeBranch");

            // update commit message (ammend)
            mgit.commit("Merged update\n\n",
                                true);
        }
        else
        {
                mgit.execute(["checkout", "master"]);
                mgit.execute("branch", "-D", "mergeBranch");
                assert(0);
        }
    }
    +/
}
