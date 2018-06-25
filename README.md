# DotfiM - A Dotfile Manager

DotfiM manages your dotfiles git repository and syncs it with your local dotfiles.
The advantage is that you can make live changes to your dotfiles which will be synced automatically to your git repository after running `dotfim`. Simply run `dotfim` on other devices without losing your setup.

## Content
- [Installation](#installation)
- [Usage](#usage)
- [Commands](#commands)


## Installation

### Requirements
- D compiler (https://dlang.org/download.html)
- DUB "Package and build management system for D" (http://code.dlang.org/download)

### Build
```
git clone git@github.com:Timoses/dotfim.git
cd dotfim
dub build
```

## Usage

Do

```
dotfim sync <gitRepo>
```

Let DotfiM manage your first dotfile:

```
dotfim add ~/.myDotfile
```

Update:

```
dotfim
```

DotfiM will add two sections to your dotfile:

1. Git Section:
  This section is synced to your gitRepo. Additions to this section will be synced to your gitRepo and pushed to remote when running `dotfim`. Running `dotfim` on another machine (using the same gitRepo) will sync the local dotfiles.

2. Local Section:
  Changes in this section are only kept locally.
  
DotfiM uses a separate branch (`dotfim`) in your git repository without touching any other branches.

#### Merging

If you make changes to a dotfile in multiple locations DotfiM will
attempt to merge. Git Merge Tool will be started if any merge conflicts
arise. Merging will temporarily create a `dotfim-merge` branch used for merging only.


## Commands

#### `dotfim`

Pull from remote gitRepo, check for changes, update dotfiles and gitfiles and eventually commit local changes and push to remote.

#### `dotfim sync <gitRepo>`

Create a folder for the git repository and run `dotfim`.

#### `dotim add <dotfile1> <dotfile2> ... <dotfileN>`

Add a dotfile to gitRepo. The file does not need to exist locally, but requires to be based upon the dotfiles path (specified during `dotfim sync` and stored in dotfim.json). Added dotfiles will be managed by DotfiM when running other commands (e.g. `dotfim`).

#### `dotfim remove <dotfile1> <dotfile2> ... <dotfileN>`

DotfiM will stop managing these dotfiles and only leave the content of the local section in each, respectively. The corresponding gitfile is left in the git repository unmanaged.

#### `dotfim ls` or `dotfim list`

List all dotfiles managed by DotfiM.

#### `dotfim unsync`

Calls `dotfim remove` on all managed dotfiles, removes DotfiM repository and deletes the dotfim.json settings.
