# DotfiM - A Dotfile Manager

DotfiM manages your git repository and syncs it with your local dotfiles.
The advantage is that you can make live changes to your dotfiles which will be synced automatically to your git repository after running `dotfim`.


## Usage

Do

```
dotfim sync <gitRepo>
```

Let dotfim manage your first dotfile:

```
dotfim add ~/.myDotfile
```

Update:

```
dotfim
```

The best way to use DotfiM is to once run `dotfim` on start-up and run it again before ending the a session (e.g. your work day on the computer).

Dotfim will add two sections to your dotfile:

1. Git Section:
  This section is synced to your gitRepo. Additions to this section will be synced to your gitRepo and pushed to remote when running `dotfim`. Running `dotfim` on another machine (using the same gitRepo) will sync the local dotfiles.

2. Local Section:
  Changes in this section are only kept locally.
  
  
## Commands

#### `dotfim`

Pull from remote gitRepo, check for changes, update dotfiles and gitfiles and eventually commit and push to remote.

#### `dotfim sync <gitRepo>`

Create a folder for the git repository and run `dotfim`.

#### `dotim add <dotfile1> <dotfile2> ... <dotfilen>`

Add a dotfile to gitRepo. The file does not need to exist locally, but requires to be a based upon the dotfiles path (specified during `dotfim sync` and stored in dotfim.json). Added dotfiles will be managed by Dotfim when running other commands (e.g. `dotfim`)

#### `dotfim remove <dotfile1> <dotfile2> ... <dotfilen>`

DotfiM will stop managing passed dotfiles and only leave the content of the local section in each, respectively. The corresponding gitfile is also removed and the changes are commited to the gitRepo.
