# DotfiM - A Dotfile Manager

With DotfiM the environment you are used to is readily available anywhere.

DotfiM manages your dotfiles Git repository and syncs it with your local dotfiles. Changes to dotfiles that are managed by DotfiM are automatically synced to your Git repository after running `dotfim sync`.
Simply run `dotfim sync` on another mashine and the changes are synchronized.

DotfiM allows local and private [passages](#passages) within dotfiles which are only stored in the git repository but are not synced to other mashines.

You can also [Test DotfiM](#test-dotfim) to see if you like it.

## Content
<!-- vim-markdown-toc GFM -->

* [Installation](#installation)
    * [Requirements](#requirements)
    * [Build](#build)
* [Usage](#usage)
    * [Passages](#passages)
    * [Test DotfiM](#test-dotfim)
* [Commands](#commands)
* [Insights](#insights)
    * [DotfiM configuration file](#dotfim-configuration-file)
    * [gitfile and dotfile](#gitfile-and-dotfile)
    * [Git repository](#git-repository)
        * [Merging](#merging)
* [Inspiring projects](#inspiring-projects)

<!-- vim-markdown-toc -->


## Installation

### Requirements
- D compiler (https://dlang.org/download.html)
- DUB "Package and build management system for D" (http://code.dlang.org/download)

*Tip: Use [D Version Manager](https://github.com/jacob-carlborg/dvm) to install both*

### Build
Download DotfiM [here](https://github.com/Timoses/dotfim/releases/latest) and build the binary:
```
cd dotfim
dub build --build=release
```

## Usage

Get DotfiM started with

```
dotfim init <gitRepo> <dir>
cd <dir>
```

Add a dotfile to be managed by DotfiM

```
dotfim add ~/.myDotfile
```

Sync dotfile with your gitfile

```
dotfim sync
```

What's a [gitfile and dotfile](#gitfile-and-dotfile)?

### Passages
Any line can be preceded by a **control line** which controls what passage the line belongs to.
Lines not preceded by a control line are treated as synchronized lines by default.

Example:
```
My synchronized line

# dotfim local
A local line, which will not be synchronized to other mashines

# dotfim private {
A private line
These lines are stored as a hashed value
in the git repository
# dotfim }
```

The format is
```
<comment_indicator> dotfim <passage>
```

Multiple lines can be assigned a passage by using `{` and `}` as delimiters:
```
<comment_indicator> dotfim <passage> {
example passage line 1
example passage line 2
<comment_comment> dotfim }
```

The following passages exist:
* `Local`: Local passages are stored in the gitfile and never synchronized to other mashines. The gitfile will additionally hold the current mashine's hostname.
* `Private`: Private behave just like local passages, however their content is first SHA-256 hashed before it is stored in the gitfile. Note that no encryption takes place, that is, the original content from which the hash was generated is not retrievable. The hash merely serves as a comparsion method to keep the correct order of private passages within dotfiles.

### Test DotfiM

To get a test environment running do the following:
```
dotfim test <testDir>
cd <testDir>
dotfim init --gitdir git --dotdir dot repo.git/
```
This will initialize DotfiM by cloning the git repository `repo.git` into the directory `git` and telling DotfiM where the home folder is (`dot`).

There are a couple of test files present (`.file1`, `.file2` and `.file3`). To get started you can change into the `git` directory and sync:
```
cd git/
dotfim sync
```


## Commands

----
**`dotfim init <gitRepo> [<directory>]`**

Initialize the git folder by cloning `<gitRepo>` into the present working directory (or `<directory>` if given) and prompt the user for its `$HOME` directory.

----
**`dotfim sync`**

Synchronize git- and dotfiles.

Pull from remote gitRepo, check for changes, update dotfiles and gitfiles and eventually commit local changes and push to remote.

----
**`dotim add <dotfile1> <dotfile2> ... <dotfileN>`**

Let DotfiM manage the given files. Files can be specified as
* absolute path in git or dot directory,
* path relative to git and dot directory.

This will automatically call `dotfim sync`.

If the dotfile already exists its content is synced to the gitfile as a `Private` passage.

To remove a file again from the list of managed files use `dotfim remove`.

----
**`dotfim remove <dotfile1> <dotfile2> ... <dotfileN>`**

DotfiM will stop managing the given files and only leave the content of local and private passages in each, respectively. The corresponding unmanaged gitfiles will be commited to the git repository containing only the previously synced passages.

----
**`dotfim ls` or `dotfim list`**

List all dotfiles managed by DotfiM.

----
**`dotfim unsync`**

Calls `dotfim remove` on all managed dotfiles and deletes [DotfiM configuration file](#dotfim-configuration-file) from the git directory.

----
**`dotfim test <dir>`**

Creates a playground test environment for experimentation under the path `<dir>`. The following parts are created:
* `<dir>/dot/`: Simulated home folder
* `<dir>/repo.git`: Simulated remote git repository

Run `cd <dir> && dotfim init --gitdor git repo.git` to get started.


## Insights

Read more about the internal workings of DotfiM here.

### DotfiM configuration file
DotfiM requires a configuration file (defaults to: `dotfim.json`) containing information about the location of your home folder. To initially create this file run `dotfim init`.

### gitfile and dotfile
DotfiM differentiates between `gitfile` and `dotfile`. `gitfile` relates to the file in the git repository while `dotfile` relates to the file in your home folder.

A line is added to both git- and dotfile (e.g. "# This dotfile is managed by DotfiM") to indicate that it is managed by DotfiM. Aside from indicating the managed state of the dotfile the line also declares the comment indicator used for that file (e.g. "#").

### Git repository
DotfiM uses a separate branch (`dotfim`) in your git repository without touching any other branches.

#### Merging

If your dotfiles are out of sync DotfiM will attempt to merge. Git Merge Tool will be started if any merge conflicts arise. Merging will temporarily create a `dotfim-merge` branch used for merging only.


## Inspiring projects
* https://github.com/kairichard/lace
* https://github.com/ajmalsiddiqui/autodot
* https://github.com/kobus-v-schoor/dotgit
* https://github.com/igr/homer
