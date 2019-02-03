module dotfim.gitdot.gitfile;

import dotfim.gitdot;
import dotfim.gitdot.file;
import dotfim.gitdot.dotfile;
import dotfim.gitdot.passage;


import std.stdio;

class Gitfile : GitDotFile
{
    this(GitDot.Settings settings, string file)
    {
        super(settings, file);
    }

    override bool opEquals(Object obj)
    {
        import std.array : empty;
        import std.conv : to;
        import std.range : popFront, front;
        import std.algorithm : each, filter;
        if (auto dot = obj.to!Dotfile)
        {
            // only compare relevant passages (not from other mashines)
            auto gits = this.passages.filter!(passage
                                => (passage.type != Passage.Type.Private &&
                                    passage.type != Passage.Type.Local)
                                    || passage.localinfo == dot.settings.localinfo);

            with (Passage.Type) foreach(dotp; dot.passages)
            {
                // no more git passages?
                if (gits.empty)
                    return false;

                auto gitp = gits.front();
                gits.popFront();

                if (gitp.type != dotp.type)
                    return false;

                if (gitp.type == Private
                        && gitp.lines != PassageHandler.hash(dotp).lines)
                    return false;
                else if (gitp.type != Private && gitp.lines != dotp.lines)
                    return false;
            }
            return true;
        }
        else
            return false;
    }

    version(unittest_all) unittest
    {
        auto gitdot = new GitDot("","");
        auto git = gitdot.git;
        auto dot = gitdot.dot;
        with(Passage.Type)
        {
            dot.passages = [Passage(Git, ["git1", "git2"]),
                            Passage(Private, ["priv1", "priv2"],
                                    gitdot.settings.localinfo)];
            git.passages = [Passage(Git, ["git1", "git2"]),
                            PassageHandler.hash(
                                Passage(Private, ["priv1", "priv2"]
                                               , gitdot.settings.localinfo))];
        }

        assert(dot == git);
        git.passages ~= Passage(Passage.Type.Local, ["otherlocal1"],
                                "someothermashine");
        assert(dot == git);
    }



}

