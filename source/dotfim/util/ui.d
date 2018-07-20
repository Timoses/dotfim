module dotfim.util.ui;

import std.path : isValidPath;
import std.stdio : write, readln;
import std.string : chomp;

bool askContinue(string question, string yes)
{
    write(question);

    string answer;
    answer = readln().chomp();

    return answer != yes ? false : true;
}

string askPath(string description, string defaultpath)
{
    string enteredPath;

    do
    {
        write(description, " (default: ",
                defaultpath, "): ");

        enteredPath = readln().chomp();

        if (enteredPath == "") enteredPath = defaultpath;
    } while (!isValidPath(enteredPath));

    return enteredPath;
}

