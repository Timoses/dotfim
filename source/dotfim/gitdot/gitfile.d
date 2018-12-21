module dotfim.gitdot.gitfile;

import dotfim.gitdot;
import dotfim.gitdot.file;
import dotfim.gitdot.dotfile;
import dotfim.gitdot.passage;


import std.stdio;

class Gitfile : GitDotFile
{
    this(ref GitDot.Settings settings, string file)
    {
        super(settings, file);
    }

    override bool opEquals(Object obj)
    {
        import std.array : empty;
        import std.conv : to;
        import std.range : popFront, front;
        import std.algorithm : each;
        if (auto dot = obj.to!Dotfile)
        {
            auto gits = this.passages;

            with (Passage.Type) foreach(dotp; dot.passages)
            {
                while (!gits.empty && gits.front.type == Local
                        && gits.front.localinfo != dotp.localinfo)
                    gits.popFront();

                // no more git passages?
                if (gits.empty)
                    return false;

                auto gitp = gits.front();
                gits.popFront();

                if (gitp.lines != dotp.lines)
                {
                    return false;
                }
            }
            return true;
        }
        else
            return false;
    }
}

