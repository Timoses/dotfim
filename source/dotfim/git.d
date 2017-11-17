module dotfim.git;

import std.stdio;

class Git
{
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
        if (execute("rev-parse", "--verify", branchName)
                .status != 0)
            execute("branch", branchName);

        execute("checkout", branchName);
    }

    @property string hash() {
        import std.string : chomp;
        return execute("rev-parse", "HEAD").output.chomp; }

    auto execute(string[] cmds ...)
    {
       import std.process : execute;
       import std.exception : enforce;
       auto res = execute(["git", "-C", this.dir] ~ cmds);
       import std.format : format;
       enforce(res.status == 0, format(
                   "An error while executing git %-(%s %)", cmds));
       return res;
    }
}
