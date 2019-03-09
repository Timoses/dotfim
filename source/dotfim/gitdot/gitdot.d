module dotfim.gitdot.gitdot;

import std.array : array;
import std.exception : enforce;
import std.file : exists;

debug import vibe.core.log;

import dotfim.dotfim;
import dotfim.gitdot.file;
import dotfim.gitdot.gitfile;
import dotfim.gitdot.dotfile;
import dotfim.gitdot.passage;


import std.stdio;

class NotManagedException : Exception
{ this(){super("Gitfile is not managed");} }

class GitDot
{
    Gitfile git;
    Dotfile dot;

    private string _relativeFile;
    @property string relfile() { return this._relativeFile; }

    class Settings
    {
        static immutable string header = "This dotfile is managed by DotfiM";
        // info string about the mashine and user running dotfim
        string localinfo;
        private string _commentIndicator;
        @property const(string) commentIndicator() const
        { return this._commentIndicator; }
        @property void commentIndicator(string newCI) {
            import std.format : format;
            enforce(this._commentIndicator.length == 0 || this._commentIndicator == newCI,
                    "Contradicting comment indicators found (%s vs %s) in %s".format(
                        this._commentIndicator, newCI, relfile));
            this._commentIndicator = newCI;
        }

        this(const string localinfo)
        {
            this.localinfo = localinfo;
        }

    }
    Settings settings;

    static @property string header() { return Settings.header; }

    @property bool managed() { return this.git.managed; }
    @property void managed(bool b)
    {
        this.git.managed = b;
        this.dot.managed = b;
    }
    @property void commentIndicator(string ci)
    {
        this.settings.commentIndicator = ci;
    }

    this(string gitfile, string dotfile, const DotfileManager.Settings dfmSettings)
    {
        import std.algorithm : commonPrefix;
        import std.range : retro, array;
        import std.conv : to;
        import std.path : pathSplitter, buildPath;

        this.settings = new Settings(dfmSettings.localinfo);

        this._relativeFile = commonPrefix(gitfile.pathSplitter.retro,
                                          dotfile.pathSplitter.retro).array
                                    .retro.buildPath
                                    .to!string;

        this.git = new Gitfile(settings, gitfile);
        this.dot = new Dotfile(settings, dotfile);

        import std.file : FileException;
        try {
            debug logDebug("GitDot: Loading Gitfile " ~ gitfile);
            this.git.load();
            debug logDebug("GitDot: Loading Dotfile " ~ dotfile);
            this.dot.load();
        } catch (FileException e) {
           debug logDebugV("GitDot: Failed loading a file - %s", e.msg);
        }
    }

    // Synchronizes from Git/Dot to Dot/Git (cross-relationship).
    // Always disregards content of the target and overwrites it with the other
    // (private passages only exist hashed in gitfile!).
    // Returns true if something was synced, false otherwise
    bool syncTo(T)()
        if (is (T : GitDotFile))
    {
        debug logDebug("GitDot.syncTo!"~T.stringof);

        import std.algorithm : map, each, all, filter, canFind;
        import std.conv : to;
        import std.typecons;
        import std.range : front, popFront, popFrontN;

        static if (is (T == Gitfile))
        {
            // sync local files to gitfile
            if (!dot.managed)
            {
                // unmanaged content is private!
                assert(dot.passages.length == 0
                        || (dot.passages.length == 1 &&
                            dot.passages[0].type == Passage.Type.Private)
                        || (dot.passages.length == 2 &&
                            [Passage.Type.Private, Passage.Type.Shebang].all!
                                (ptype => dot.passages.canFind!(p => p.type == ptype))
                           ),
                        "Unmanaged dotfile should only have one private passage "
                        ~ "containing all its content and optionally a shebang "
                        ~ "passage!\n\t" ~ dot.passages.to!string);

                auto privatePassages = dot.passages!(Passage.Type.Private);
                assert(privatePassages.length <= 1,
                        "Unmanaged dotfile should only have up to 1 private passage containing all its content!\n\t" ~ privatePassages.to!string);

                auto shebangPassages = dot.passages!(Passage.Type.Shebang);
                assert(shebangPassages.length <= 1, "Only up to 1 shebang passage "
                        ~ "expected!\n\t" ~ shebangPassages.to!string);

                Passage[] addPassages;
                // Does Git already contain the passages?
                // (Usually not the case, though one tests case provokes it!)
                if (privatePassages.length && !git.passages.canFind!(
                        passage => passage == PassageHandler.hash(privatePassages[0])))
                    addPassages ~= PassageHandler.hash(privatePassages[0]);
                if (shebangPassages.length && !git.passages.canFind!(gitp => gitp ==
                                        shebangPassages[0]))
                    addPassages ~= shebangPassages[0];

                if (addPassages.length == 0)
                    return false;


                git.passages ~= addPassages;
                return true;
            }
            else with(Passage.Type)
            {
                debug logTrace("GitDot.syncTo: dot.managed");

                /* Create a Matrix where
                    1st column: Dotfile passage,
                    2nd column: Gitfile passage,
                    3rd column: Passages that don't belong to this Dotfile
                                (e.g. local passages from other mashines).
                                This column is optional.
                   Scenarios:
                    * [ Pdot | Pgit ] if Pdot and Pgit are equal.
                    * [ Pdot | null ] then Pdot is a new passage to be added.
                    * [ null | Pgit ] then Pgit was removed from dotfile.
                    * [ null | null | Pgit,other ] for git passages that do not
                      belong to this Dotfile
                    * [ Pdot ] if git has no more passages

                   Afterwards, to get the new contents of gitfile, merge
                   columns 1 and 3.

                   Storing redundant information in the matrix supports better
                   debugging.
                */
                auto gits = git.passages;
                Nullable!Passage[][] matrix;
                foreach (dotp; dot.passages)
                {
                    while (gits.length &&
                            (gits.front.type == Local || gits.front.type == Private)
                            && this.settings.localinfo != gits.front.localinfo)
                    {
                        matrix ~= [Nullable!Passage(), Nullable!Passage(),
                                    gits.front.nullable];
                        gits.popFront();
                    }

                    if (gits.length)
                    {
                        auto gitp = gits.front;
                        gits.popFront;

                        if ((gitp.type == Private &&
                                PassageHandler.hash(dotp) == gitp))
                            matrix ~= [dotp.nullable, gitp.nullable];
                        else if (gitp == dotp)
                            matrix ~= [dotp.nullable, gitp.nullable];
                        else
                            matrix ~= [[dotp.nullable, Nullable!Passage()],
                                       [Nullable!Passage(), gitp.nullable]];
                    }
                    else
                        matrix ~= [dotp.nullable];
                }
                // deal with remaining passages in gits
                foreach (gitp; gits)
                {
                    if ((gitp.type == Local || gitp.type == Private)
                            && this.settings.localinfo != gitp.localinfo)
                        matrix ~= [Nullable!Passage(), Nullable!Passage(),
                                    gitp.nullable];
                    else
                        matrix ~= [Nullable!Passage(), gitp.nullable];
                }

                debug {
                    import std.string : join;
                    logTrace("GitDot.syncTo: Matrix:\n%s",
                        matrix.map!(row => "\t"~row.to!string).array.join("\n"));
                }
                auto passages = matrix.map!((row) {
                    if (row.length == 3)
                    {
                        assert(row[0..2].all!(n => n == Nullable!Passage()));
                        assert(row[2].type == Passage.Type.Local ||
                               row[2].type == Passage.Type.Private);
                        return row[2];
                    }

                    if (!row[0].isNull && row[0].type == Private)
                        return PassageHandler.hash(row[0]).nullable;
                    else
                        return row[0];
                }).filter!(n => !n.isNull).map!(n => n.get).array;

                git.passages = passages;
            }

            // todo: actually check if it syncs something
            return true;
        }

        static if (is (T == Dotfile)) with (Passage.Type)
        {
            auto dots = this.dot.passages;
            // only use local/private sections pertaining to this mashine
            auto gits = this.git.passages.filter!(passage
                                => (passage.type != Private && passage.type != Local)
                                    || passage.localinfo == this.settings.localinfo);

            Nullable!Passage[][] matrix;
            /* Recursively search for matching dotp passage. If none found,
               add [gitp,null]. If found, add [null, dotp_x] where dotp_x all
               dotp passed before hitting the match, and also add matched [gitp, dotp].
               If gitp is private: add [dotp, dotp].
               Adding a private passage from gitfile or removing a private passage
               from dotfile (missing private passage in gitfile) is not allowed! */
   gitloop: foreach (gitp; gits)
            {
                assert((gitp.type != Local && gitp.type != Private) ||
                        (gitp.localinfo == this.git.settings.localinfo),
                        "Other mashine git passages should have been filtered out!");

                Passage[] dotsPassed;
                foreach (dotp; dots)
                {
                    if (gitp.type != dotp.type)
                    {
                        dotsPassed ~= dotp;
                        continue;
                    }

                    if ((gitp.type == Private &&
                            PassageHandler.hash(dotp) == gitp) ||
                            gitp == dotp)
                    {
                        // TODO: is it fine popping from the iterated range?
                        //       Should be, since we break off the iteration
                        //       below!
                        dots.popFrontN(dotsPassed.length + 1);

                        matrix ~= dotsPassed.map!(dotpassed =>
                                [Nullable!Passage(), dotpassed.nullable]).array;

                        if (gitp.type == Private)
                            matrix ~= [dotp.nullable, dotp.nullable];
                        else
                            matrix ~= [gitp.nullable, dotp.nullable];
                        continue gitloop;
                    }
                    else
                        dotsPassed ~= dotp;
                }

                // didn't find a matching dotp!
                enforce(gitp.type != Private, "Incoming private passage "
                        ~"from Gitfile " ~ this.git.file ~ " which could "
                        ~ "not be matched! "
                        ~ "Gitfiles should not introduce new private passages!");
                matrix ~= [gitp.nullable, Nullable!Passage()];
            }
            // add rest of dots
            foreach (dotp; dots)
            {
                // gitfile tries to remove a private passage??
                enforce(dotp.type != Private, "Syncing to Dotfile: Removing "
                        ~ "a private passage from Dotfile!!?? Gitfiles should not "
                        ~ "manipulate private passages!");
                matrix ~= [Nullable!Passage(), dotp.nullable];
            }

            debug {
                import std.string : join;
                logTrace("GitDot.syncTo: Matrix:\n%s",
                    matrix.map!(row => "\t"~row.to!string).array.join("\n"));
            }

            this.dot.passages = matrix.filter!(row => !row[0].isNull)
                                      .map!(row => row[0].get).array;

            this.dot.hash = this.git.hash;
            this.dot.managed = this.git.managed;

            // todo: actually check if it synced something
            return true;
        }
    }
    version(unittest_all) unittest
    {
        auto gitdot = new GitDot("","", DotfileManager.Settings());
        gitdot.commentIndicator = "#";
        gitdot.managed = true;
        gitdot.git.passages = [
            Passage(Passage.Type.Git, ["git1"]),
            Passage(Passage.Type.Local, ["local1", "local2"],
                    gitdot.settings.localinfo)];
        gitdot.dot.passages = [
            Passage(Passage.Type.Git, ["git1"]),
            Passage(Passage.Type.Git, ["git2"]),
            Passage(Passage.Type.Local, ["local1", "local2"],
                    gitdot.settings.localinfo)];
        gitdot.syncTo!Gitfile();
        assert(gitdot.git.passages == [
            Passage(Passage.Type.Git, ["git1"]),
            Passage(Passage.Type.Git, ["git2"]),
            Passage(Passage.Type.Local, ["local1", "local2"],
                    gitdot.settings.localinfo)]);
    }
    version(unittest_all) unittest
    {
        auto gitdot = new GitDot("","", DotfileManager.Settings());
        gitdot.commentIndicator = "'";
        gitdot.managed = true;
        with (Passage.Type) gitdot.git.passages = [
            Passage(Local, ["other1"], "othermashine"),
            PassageHandler.hash(
                Passage(Private, ["priv1", "priv2"], gitdot.settings.localinfo)),
            Passage(Git, ["git1", "git2"]),
            Passage(Local, ["local1"], gitdot.settings.localinfo),
            Passage(Git, ["git3"])];
        with (Passage.Type) gitdot.dot.passages = [
            Passage(Private, ["priv1", "priv2"], gitdot.settings.localinfo),
            Passage(Git, ["git1", "git2"]),
            Passage(Local, ["local1"], gitdot.settings.localinfo)];

        gitdot.syncTo!Dotfile();
        with (Passage.Type) assert(gitdot.dot.passages == [
                Passage(Private, ["priv1", "priv2"], gitdot.settings.localinfo),
                Passage(Git, ["git1", "git2"]),
                Passage(Local, ["local1"], gitdot.settings.localinfo),
                Passage(Git, ["git3"])]);
    }
}

