module dotfim.section.section;

abstract class Section
{
    enum Part { Header, Content, Footer }

    // true if section successfully was loaded in SectionHandler.load
    bool bLoaded;

    // set during handle() if section requires an update
    bool bRequiresUpdate;

    // name of the section
    string name;

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

    void append(Part part, string[] entry)
    {
        this.entries[part].lines ~= entry;
    }

    string[] get(Part part)
    {
        return this.entries[part].lines;
    }

    void setEntryComment(Part part, bool b)
    {
        this.entries[part].isComment = b;
    }

    string[] getHeaderTitle();
    string[] getHeader();
    string[] getFooter();

    // load section from lines, lines has to contain
    // the complete section, no more, no less
    bool load(string[] lines, string commentIndicator)
    {
        import std.algorithm;

        auto doSplit = function (string[] mlines) {
            return mlines.findSplit!((a,b) => a.canFind(b))([Section.metaSeparator]);
        };

        auto split = doSplit(lines);

        import std.string : empty;
        import std.exception : enforce;
        enforce(!split[1].empty, "Could not find metaSeparator in section ", this.name);

        // set entry and remove commentIndicator if applicable
        void setRemoveCommentIndicator(Part part, string[] mlines)
        {
            import std.range : array;
            set(part, mlines.map!((string line) {
                import std.string : indexOf, chompPrefix;
                return (this.entries[part].isComment
                        && line.indexOf(commentIndicator) == 0)
                    // return without commentIndicator
                    ? line[commentIndicator.length .. $].chompPrefix(" ")
                    : line; }
                ).array);
        }

        // Header
        setRemoveCommentIndicator(Part.Header, split[0]);

        split = doSplit(split[2]);
        enforce(!split[1].empty, "Could not find metaSeparator in section ", this.name);

        // Content
        setRemoveCommentIndicator(Part.Content, split[0]);
        // Footer
        setRemoveCommentIndicator(Part.Footer, split[2]);

        this.bLoaded = true;

        return this.bLoaded;
    }

    // generates the sectikn entries from scratch
    void generate();

    string[] build(string commentIndicator)
    {
        string[] lines;

        lines ~= commentIndicator ~ this.sectionSeparator
                    ~ commentIndicator;
        lines ~= build(Part.Header, commentIndicator);
        lines ~= commentIndicator ~ this.metaSeparator;
        lines ~= build (Part.Content, commentIndicator);
        lines ~= commentIndicator ~ this.metaSeparator;
        lines ~= build(Part.Footer, commentIndicator);
        lines ~= commentIndicator ~ this.sectionSeparator
                    ~ commentIndicator;

        return lines;
    }

    string[] build(Part part, string commentIndicator)
    {
        string prefix = "";
        if (this.entries[part].isComment)
            prefix = commentIndicator ~ " ";
        import std.algorithm : map;
        import std.range : array;
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

    this(string commentIndicator)
    {
        import std.stdio;
        loadAvailableSections();
        this.commentIndicator = commentIndicator;
    }

    // load all classes derived from Section
    void loadAvailableSections()
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

    // Delivers matching raw lines to the appropriate section
    // and returns unmatched lines
    string[] load(string[] lines)
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
                   section.load(split[0], this.commentIndicator);
                   break;
               }
            }

            split = doSplit(split[2]);
        }

        import std.exception : enforce;
        // should have handled/found all sections now
        foreach (section; this.sections)
            enforce(section.bLoaded, "Section " ~ section.name ~
                    " could not properly be loaded or found");

        unhandledLines ~= split[0];

        return unhandledLines;
    }

    void generateSections()
    {
        foreach (sec; this.sections)
            sec.generate();
    }

    string[] getAllSectionsLines(string separator)
    {
        string[] lines;
        foreach (sec; this.sections)
        {
            lines ~= sec.build(this.commentIndicator) ~ separator;
        }
        return lines;
    }

    string[] getSectionLines(alias T)()
    {
        foreach (sec; this.sections)
        {
            if (cast(T)sec)
            {
                return sec.build(this.commentIndicator);
            }
        }
        return [];
    }

    Section getSection(alias T)()
    {
        foreach (sec; this.sections)
        {
            if (cast(T)sec)
            {
                return sec;
            }
        }
        return null;
    }
}

struct SectionEntry
{
    bool isComment;

    string[] lines;
}

