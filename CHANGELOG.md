# Changelog

## v0.1.0 (2019-03-03)
### Added
* Diverged branches are automatically merged during syncing
* Add `dotfim test` for easily creating a dotfim test environment
* Passages
    * Private passages (see [Passages](https://github.com/Timoses/dotfim#passages))
        * are not readable in gitfile (hashed)
    * Local and private passages display the hostname where they originated from
* Environment variables
    * `DOTFIM_LOCALINFO`: Used as the hostname for local and private passages (otherwise output of `hostname` is used)
* Support for Docker
    * DotfiM can be entirely used from a container
    * Test environment can be spun up with `docker/test.sh`
* Files with a shebang notation at the top are now properly synced (shebang line remains in first line)
### Changed
* Passages replace Sections
    * Previously only one git section and one local section was used
    * With passages any amount of git, local and private passages can be used anywhere in the file
    * See also:
        * [Passages](https://github.com/Timoses/dotfim#passages)
        * [Multiple sections unwieldy](https://github.com/Timoses/dotfim/issues/4)
        * [Control statements](https://github.com/Timoses/dotfim/issues/7)
* Update `dotfim` cli interaction
    * `dotfim init`:
        * Previously `dotfim sync`
        * Now accepts second argument to provide directory where repository should be cloned into
    * `dotfim sync`
        * Syncs dotfiles (previously done by `dotfim`)
    * `dotfim` now only lists possible actions
* Only `dotfim` branch is cloned during `dotfim init`
* DotfiM settings file `dotfim.json` is now located in the git folder
### Fixed
* Fix various issues with setting up, cloning and updating the git repository
* Fix bug where previous dotfile content was disregarded
* Fix enforcing only dotfiles (prefixed with `.`) may be added
### Internal
* Provide unittests for various scenarios in `tests` folder
* Simplify loading gitfiles in DotfileManager
