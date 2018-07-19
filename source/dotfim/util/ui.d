module dotfim.util.ui;

static bool askContinue(string question, string yes)
{
    import std.stdio : write, readln;
    write(question);

    string answer;
    import std.string : chomp;
    answer = readln().chomp();

    return answer != yes ? false : true;
}
