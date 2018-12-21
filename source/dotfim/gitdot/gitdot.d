module dotfim.gitdot.gitdot;

import std.exception : enforce;
import std.file : exists;

debug import vibe.core.log;

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


    struct Settings
    {
        static immutable string header = "This dotfile is managed by DotfiM";
        // info string about the mashine and user running dotfim
        static string localinfo;
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
        this.git.commentIndicator = ci;
        this.dot.commentIndicator = ci;
    }

    static this()
    {
        import std.socket : Socket;
        this.settings.localinfo = Socket.hostName;
    }

    this(string gitfile, string dotfile)
    {
        import std.algorithm : commonPrefix;
        import std.range : retro, array;
        import std.conv : to;
        import std.path : pathSplitter, buildPath;
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

    // returns true if something was synced, false otherwise
    bool syncTo(T)()
        if (is (T : GitDotFile))
    {
        debug logDebug("GitDot.syncTo!"~T.stringof);

        static if (is (T == Gitfile))
        {
            // sync local files to gitfile
            if (!dot.managed)
            {
                import std.algorithm : any;
                // check if the same local dotfile passage from unmanaged file
                // was already synced from somewhere...
                if (!git.passages!(Passage.Type.Local)
                        .any!(passage =>
                            passage == Passage(Passage.Type.Local,
                                               dot.raw,
                                               this.settings.localinfo)))
                {
                    git.passages ~= Passage(Passage.Type.Local, dot.raw,
                            this.settings.localinfo);
                    return true;
                }
                else
                    return false;
            }
            else
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
                import std.algorithm : map, each, all, filter;
                import std.conv : to;
                import std.typecons;
                import std.range : front, popFront;
                auto gits = git.passages;
                Nullable!Passage[][] matrix;
                foreach (dotp; dot.passages) with(Passage.Type)
                {
                    while (gits.length && gits.front.type == Local
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

                        if (dotp == gitp)
                            matrix ~= [dotp.nullable, gitp.nullable];
                        else
                            matrix ~= [[dotp.nullable, Nullable!Passage()],
                                       [Nullable!Passage(), gitp.nullable]];
                    }
                    else
                        matrix ~= [dotp.nullable];
                }
                // deal with remaining passages in gits
                foreach (gitp; gits) with (Passage.Type)
                {
                    if (gitp.type == Local
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
                        assert(row[2].type == Passage.Type.Local);
                        return row[2];
                    }
                    return row[0];
                }).filter!(n => !n.isNull).map!(n => n.get).array;

                git.passages = passages;
            }

            // todo: actually check if it syncs something
            return true;
        }

        static if (is (T == Dotfile))
        {
            this.dot.passages.length = 0;

            foreach (passage; this.git.passages)
            {
                if (passage.type == Passage.Type.Git
                        || (passage.type == Passage.Type.Local
                        && passage.localinfo == this.settings.localinfo))
                    this.dot.passages ~= Passage(passage);
            }

            this.dot.commentIndicator = this.git.commentIndicator;
            this.dot.hash = this.git.hash;
            this.dot.managed = this.git.managed;

            // todo: actually check if it synced something
            return true;
        }
    }
    unittest
    {
        auto gitdot = new GitDot("","");
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
}

