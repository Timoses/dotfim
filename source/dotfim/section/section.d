module dotfim.section.section;

import dotfim.dotfile;

abstract class Section
{
    enum Part { Header, Content, Footer }

    // true if section was handled in SectionHandler.handleFromRaw
    bool bHandled;

    // set during handle() if section requires an update
    bool bRequiresUpdate;

    // name of the section
    string name;

    string[] lines;

    private
    {
        SectionEntry[Part] entries;
    }

    static immutable string sectionSeparator = "-------------DotFiM-------------";
    static immutable string metaSeparator = " - - - - - - - - - - -";

    this()
    {
        import std.traits : EnumMembers;
        foreach (part; EnumMembers!Part)
            this.entries[part] = SectionEntry();

        this.setEntryComment(Part.Header, true);
        this.setEntryComment(Part.Footer, true);
    }

    void set(Part part, string[] entry)
    {
        this.entries[part].lines = entry;
    }

    void setEntryComment(Part part, bool b)
    {
        this.entries[part].isComment = b;
    }

    string[] getHeaderTitle();
    string[] getHeader();
    string[] getFooter();

    // handle incoming lines and trigger appropriate actions
    // if required. Called when section exists.
    bool handle(string[] lines);

    // generates the section entries from scratch
    void generate();

    string[] getLines(string commentIndicator)
    {
        import std.string;
        if (lines.empty)
        {
            lines ~= commentIndicator ~ this.sectionSeparator
                        ~ commentIndicator;
            lines ~= create(Part.Header, commentIndicator);
            lines ~= commentIndicator ~ this.metaSeparator;
            lines ~= create (Part.Content, commentIndicator);
            lines ~= commentIndicator ~ this.metaSeparator;
            lines ~= create(Part.Footer, commentIndicator);
            lines ~= commentIndicator ~ this.sectionSeparator
                        ~ commentIndicator;
        }
        return lines;
    }

    string[] create(Part part, string commentIndicator)
    {
        string prefix = "";
        if (this.entries[part].isComment)
            prefix = commentIndicator ~ " ";
        import std.algorithm : map;
        import std.range;
        return this.entries[part].lines.map!((a) => prefix ~ a).array;
    }

    bool identifiesWith(string[] lines)
    {
        import std.algorithm;
        return lines.canFind!((a,b) => a.canFind(b))(this.getHeaderTitle);
    }
}

//// SectionHandler exists per Dotfile and loads available
//// sections.
class SectionHandler
{
    Section[] sections;

    string commentIndicator;

    this(in Dotfile df)
    {
        import std.stdio;
        loadAvailableSections(df);
        this.commentIndicator = df.commentIndicator;
    }

    // load all classes derived from Section
    void loadAvailableSections(in Dotfile df)
    {
        foreach (mod; ModuleInfo)
        {
            foreach(classinfo; mod.localClasses)
            {
                if (classinfo.base is Section.classinfo)
                {
                    sections ~= cast(Section)classinfo.create();
                }
            }
        }
    }

    // Delivers matching raw lines to the appropriate section for
    // further handling and returns unmatched lines
    string[] handleFromRaw(string[] lines)
    {
        import std.algorithm;

        auto doSplit = function (string[] mlines) {
            return mlines.findSplit!((a,b) => a.canFind(b))([Section.sectionSeparator]);
        };

        import std.string;
        string[] unhandledLines;
        auto split = doSplit(lines);
        while (!split[1].empty)
        {
            unhandledLines ~= split[0];

            split = doSplit(split[2]);

            import std.exception : enforce;
            enforce(!split[1].empty, "Could not find a matching ending section separator");

            foreach (section; this.sections)
            {
               if (section.identifiesWith(split[0]))
               {
                   section.handle(split[0]);
                   break;
               }
            }

            split = doSplit(split[2]);
        }

        import std.exception : enforce;
        // should have handled/found all sections now
        foreach (section; this.sections)
            enforce(section.bHandled, "Section " ~ section.name ~
                    " could not properly be handled or found");

        unhandledLines ~= split[0];

        return unhandledLines;
    }

    void generateSections()
    {
        foreach (sec; this.sections)
            sec.generate();
    }

    string[] getSections(string separator)
    {
        string[] lines;
        foreach (sec; this.sections)
        {
            lines ~= sec.getLines(this.commentIndicator) ~ separator;
        }
        return lines;
    }

    string[] getSection(alias T)()
    {
        pragma(msg, T);
        foreach (sec; this.sections)
        {
            if (cast(T)sec)
            {
                return sec.getLines(this.commentIndicator);
            }
        }
        return [];
    }
}

struct SectionEntry
{
    bool isComment;

    string[] lines;
}

