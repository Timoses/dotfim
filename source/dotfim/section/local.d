module dotfim.section.local;


import dotfim.section;

class LocalSection : Section
{
    this()
    {
        this.name = "Local";
    }

    override string[] getHeaderTitle()
    {
        return ["DotfiM - Local Section"];
    }

    override string[] getHeader()
    {
        return getHeaderTitle() ~
            [" This section is only kept locally and will not be synced"];
    }

    override string[] getFooter()
    {
        return ["DotfiM - end of Local Section"];
    }

    override void generate()
    {
        this.set(Part.Header, this.getHeader());
        this.set(Part.Footer, this.getFooter());
    }
}
