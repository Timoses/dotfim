# DotfiM - A Dotfile Manager

DotfiM manages your dotfiles git repository and syncs it with your local dotfiles.
The advantage is that you can make changes to your dotfiles which will be synced automatically to your git repository after running `dotfim`. Simply run `dotfim` on other devices without losing your setup.

## Content
<!-- vim-markdown-toc GFM -->

* [Installation](#installation)
    * [Requirements](#requirements)
    * [Build](#build)
* [Usage](#usage)
* [Commands](#commands)
* [Insights](#insights)
    * [`dotfim.json` settings file](#dotfimjson-settings-file)
    * [gitfile and dotfile](#gitfile-and-dotfile)
        * [gitfile](#gitfile)
        * [dotfile](#dotfile)
    * [Git repository](#git-repository)
        * [Merging](#merging)

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
dotfim init <gitRepo>
```

Add a dotfile to be managed by DotfiM

```
dotfim add ~/.myDotfile
```

Sync dotfile with your gitfile

```
dotfim
```

What's a [gitfile and dotfile](#gitfile-and-dotfile)?


## Commands

----
**`dotfim`**

Pull from remote gitRepo, check for changes, update dotfiles and gitfiles and eventually commit local changes and push to remote.

----
**`dotfim init <gitRepo>`**

Initializes the git folder by cloning `<gitRepo>` into the present working directory and prompts the user for its `$HOME` directory.

----
**`dotim add <dotfile1> <dotfile2> ... <dotfileN>`**

Add a dotfile to gitRepo. The file does not need to exist locally, but requires to be based upon the dotfiles path (specified during `dotfim init` and stored in dotfim.json). Added dotfiles will be managed by DotfiM when running other commands (e.g. `dotfim`).

----
**`dotfim remove <dotfile1> <dotfile2> ... <dotfileN>`**

DotfiM will stop managing these dotfiles and only leave the content of the local section in each, respectively. The corresponding gitfile is left in the git repository unmanaged.

----
**`dotfim ls` or `dotfim list`**

List all dotfiles managed by DotfiM.

----
**`dotfim unsync`**

Calls `dotfim remove` on all managed dotfiles, removes DotfiM repository and deletes the dotfim.json settings.

----
**`dotfim test <dir>`**

Creates a playground test environment for experimentation under the path `directory`. The following parts are created:
* `<dir>/dot/`: Simulated home folder
* `<dir>/repo.git`: Simulated remote git repository

Run `cd <dir> && dotfim init repo.git` to get started.


## Insights

Read more about the internal workings of DotfiM here.

### `dotfim.json` settings file
DotfiM requires a settings file `dotfim.json` containing information about the locations of your home folder and the local git repository folder and further stores the remote git repository url. To initially create this file run `dotfim init`.

### gitfile and dotfile
DotfiM differentiates between `gitfile` and `dotfile`. `gitfile` relates to the file in the git repository while `dotfile` relates to the file in your home folder.

#### gitfile
DotfiM adds a header line (e.g. "# This file is managed by DotfiM") to track whether a gitfile is currently managed by DotfiM.

#### dotfile
A managed dotfile (`dotfim add`) will contain two sections:

* Git Section:
  Contents in this section are synced with the gitfile.

* Local Section:
  Contents in this section are only kept locally.

Adding lines outside of these sections will append them to the local section the next time `dotfim` is run.

### Git repository
DotfiM uses a separate branch (`dotfim`) in your git repository without touching any other branches.

#### Merging

If your dotfiles are out of sync DotfiM will attempt to merge. Git Merge Tool will be started if any merge conflicts arise. Merging will temporarily create a `dotfim-merge` branch used for merging only.
