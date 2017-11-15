module dotfim.section.git;


import dotfim.section;
import dotfim.dotfile;

class GitSection : Section
{
    this()
    {
        this.name = "Git";
    }

    override string[] getHeaderTitle()
    {
        return ["DotFiM - Git Section"];
    }

    override string[] getHeader()
    {
        return getHeaderTitle() ~
                [" Do not edit this section directly.",
                 " To make changes add them to the Update Section.",
                 " Git Commit Hash: "];// ~ this.gitHash];
    }

    override string[] getFooter()
    {
        return ["DotFiM - end of Git Section"];
    }

    override bool handle(string[] lines)
    {
        // outline:
        //  1. gitHash differs?
        //      ?? changes made to home commit
        //          git-merge-file curGit oldGitHashCommit curHome
        // lines have correct version?
        import std.algorithm;
//        if (lines.canFind!((a,b) => a.canFind(b))([this.gitHash]))
//            this.isCorrectVersion = true;
//
//        // retrieve the section's content
//        string[] content = lines
//                .findSplitAfter!((a,b) => a.canFind(b))([this.metaSeparator])[1]
//                .findSplitBefore!((a,b) => a.canFind(b))([this.metaSeparator])[0];
//
//        // read contents of gitFile
//        import std.conv;
//        import std.stdio : File;
//        File git = File(this.gitFile, "r");
//        string[] gitContent;
//        foreach (line; git.byLine)
//            gitContent ~= line.to!string;
//
//        import std.range;
//        string[] commentLine = gitContent.take(1);
//
//        // git Section was updated? (first line is commentLine)
//        if (gitContent.drop(1).array != content)
//        {
//            import std.exception : enforce;
//            import std.format : format;
//            import std.path : baseName;
//            // can't commit new git section if not the newest was changed
//            enforce(this.isCorrectVersion, format("The git section version in home folder differs from the most current version (%s)", this.gitFile.baseName));
//
//            string[] newGitFile = commentLine ~ content;
//
//            // replace old git file with new one
//            import std.file;
//            std.file.remove(this.gitFile);
//            git = File(this.gitFile, "w");
//            foreach (line; newGitFile)
//                git.writeln(line);
//            git.close();
//
//            // commit changes
//            import std.path : baseName;
//            string commitText =
//                this.gitFile.baseName ~ `: dotfim update`;
//            executeGit(["add", this.gitFile]);
//            executeGit(["commit", "-m", commitText]);
//        }
//
        return true;
    }

    override void generate()
    {
        this.set(Part.Header, this.getHeader());
        this.set(Part.Footer, this.getFooter());

        // load gitFile content
//        string gitFileContent;
//        import std.stdio;
//        import std.conv;
//        import std.string;
//        File git = File(this.gitFile, "r");
//        foreach(line; git.byLine)
//            gitFileContent ~= line.to!string ~ "\n";
//        git.close;
//
//        import std.range;
//        import std.algorithm;
//        // remove commentIndicator line and empty lines
//        this.set(Part.Content,
//            gitFileContent.splitLines
//                .drop(1));
    }
}
