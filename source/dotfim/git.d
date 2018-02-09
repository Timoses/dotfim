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
}
