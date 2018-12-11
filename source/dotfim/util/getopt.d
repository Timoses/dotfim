module dotfim.util.getopt;

import std.getopt;

static T process(T)(ref string[] args)
{
    T result = T(args);

    if (result.helpWanted)
    {
        defaultGetoptPrinter("DotfiM " ~ args[0]
                ~ " - the following options are available:", result.options);
    }

    return result;
}

