module dotfim.util.test;

version(unittest)
{
    import std.file;
    import std.path;
    import std.range;
    import std.algorithm;

    import dotfim.dotfim;
    import dotfim.git;

    static string testfolder;
    static immutable string dotfolder;
    static immutable string gitfolder;
    static immutable string remotefolder;
    static immutable string settingsfile;
    static immutable string testfile;

    static DotfileManager.Settings settings;

    static this()
    {
        testfolder = tempDir.buildPath("dotfim/test");
        import std.random : choice, uniform;
        import std.stdio;
    //    while (testfolder.exists)
     //       testfolder ~= uniform('a', 'z');
        if(exists(testfolder))
            testfolder.rmdirRecurse;
        testfolder.mkdirRecurse;

        dotfolder = testfolder.buildPath("dot");
        gitfolder = testfolder.buildPath("git");
        remotefolder = testfolder.buildPath("remote");
        [dotfolder, remotefolder].each!mkdirRecurse;
        settingsfile = testfolder.buildPath("dotfim.json");

        settings.bFirstSync = false;
        settings.dotPath = dotfolder;
        settings.gitPath = gitfolder;
        settings.settingsFile = settingsfile;

        testfile = dotfolder.buildPath(Testdotfile.name);
    }

    static ~this()
    {
        //rmdirRecurse(testfolder);
    }


    static struct Testdotfile
    {
        static immutable string name = ".test";
        static immutable string text = q"(
TestDotfile line 1
TestDotfile line 2
TestDotfile line 3)";
        static void create()
        { buildPath(dotfolder, name).write(text); }
    }


    DotfileManager prepareExample()
    {
        Testdotfile.create;
        Git.staticExecute(remotefolder, "init", "--bare");
        import dotfim.cmd : Init;
        Init s;
        settings.gitRepo = remotefolder;
        s.gitRepo = remotefolder;
        settings.settingsFile = settingsfile;
        return s.setup(settings);
    }
}
