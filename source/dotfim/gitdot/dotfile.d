module dotfim.gitdot.dotfile;

import dotfim.gitdot;
import dotfim.gitdot.file;
import dotfim.gitdot.gitfile;

class Dotfile : GitDotFile
{
    this(ref GitDot.Settings settings, string file)
    {
        super(settings, file);
    }

    override bool opEquals(Object obj)
    {
        import std.conv : to;
        if (auto git = obj.to!Gitfile)
        {
            return git.opEquals(this);
        }
        else
            return false;
    }
}

